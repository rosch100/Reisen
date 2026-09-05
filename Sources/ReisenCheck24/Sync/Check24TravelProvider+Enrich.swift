import Foundation
import WebKit
import ReisenDomain
import ReisenProviders
import ReisenDiagnostics

extension Check24TravelProvider {
    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        guard let url = URL(string: ref.externalUrl) else {
            throw Check24ProviderError.navigationFailed
        }
        await recordDiagnosticPhase(
            "enrichment",
            event: "started",
            result: .started,
            url: url,
            reason: "booking_type=\(ref.bookingType)"
        )
        try await load(url: url, in: webView)
        await dismissBookingChooserIfNeeded(
            in: webView,
            needles: [ref.externalUrl, url.lastPathComponent]
        )
        if ref.bookingType == .carRental {
            guard try await waitForCarRentalDetailReady(in: webView) else {
                await recordDiagnosticPhase(
                    "enrichment",
                    event: "readiness_failed",
                    result: .failed,
                    url: url,
                    reason: "car_rental_readiness"
                )
                throw Check24ProviderError.navigationFailed
            }
            let snapshot = try await snapshotHTML(from: webView)
            await recordDiagnosticPhase(
                "enrichment",
                event: "completed",
                result: .succeeded,
                url: url
            )
            return Self.carRentalEnrichment(html: snapshot.html)
        }
        var hotelReadinessSkipped = false
        if ref.bookingType == .hotel {
            let detailReady = try await waitForHotelDetailReady(in: webView)
            _ = try await waitForHotelInfoAddressPayload(in: webView)
            if !detailReady {
                hotelReadinessSkipped = true
                await recordDiagnosticPhase(
                    "enrichment",
                    event: "readiness_failed",
                    result: .skipped,
                    url: url,
                    reason: "hotel_detail_readiness"
                )
            }
        }
        let snapshot = try await snapshotHTML(from: webView)
        let policy = CancellationPolicyParser().parseCancellationPolicy(from: snapshot.html)
        let details = BookingDetailsParser().parse(from: snapshot.html, bookingType: ref.bookingType)
        let stay = HotelCheckInOutParser().parse(from: snapshot.html)
            .merging(place: Check24HotelInfoParser.parse(from: snapshot.html))
        var passengers: [BookingPassenger]? = nil
        var baggageSoftFailed = false
        if ref.bookingType == .flight {
            let parser = Check24FlightPassengersAndLuggageParser()
            let guestNames = parser.guestNames(from: snapshot.html)
            if !guestNames.isEmpty, let statusURL = check24StatusURL(from: ref.externalUrl) {
                do {
                    let statusText = try await webView.fetchAuthenticatedText(
                        url: statusURL,
                        accept: "application/json, text/plain, */*",
                        referer: ref.externalUrl
                    )
                    let baggage = try parser.baggageAllowances(from: statusText)
                    let built = parser.buildPassengers(
                        guestNames: guestNames,
                        baggageAllowances: baggage
                    )
                    passengers = built.isEmpty ? nil : built
                } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
                    throw Check24ProviderError.sessionNotEstablished
                } catch {
                    await recordDiagnosticPhase(
                        "enrichment",
                        event: "baggage_failed",
                        result: .failed,
                        url: statusURL,
                        reason: error.localizedDescription
                    )
                    passengers = nil
                    baggageSoftFailed = true
                }
            }
        }

        // Mehrzimmer-Detailseite: „basketDetails.basketPrice“ ist der Bestell-Gesamtpreis.
        // Deshalb parsen wir den Basket und übernehmen Preis + `roomItems` konsistent.
        var rate: BookingRateDetails
        if let basket = HotelBasketParser.parse(from: snapshot.html),
           let basketRate = mapBasketRateDetails(basket: basket, details: details) {
            rate = basketRate
        } else {
            rate = details.asRateDetails()
        }

        let hints = StayHintHTMLExtractor.extract(
            from: snapshot.html,
            providerRaw: ProviderID.check24.rawValue
        )
        let mappedDeadlines = policy.deadlines.map(\.asDomain)
        let enrichment = DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .check24,
                bookingType: ref.bookingType,
                locationTo: stay.locationTo,
                locationToAddress: stay.locationToAddress,
                deadlines: mappedDeadlines,
                rateDetails: rate,
                hotelCheckInMinutes: stay.checkInMinutes,
                hotelCheckOutMinutes: stay.checkOutMinutes,
                passengers: passengers ?? [],
                guestHints: hints
            )
        )
        let completionReason: String?
        if baggageSoftFailed {
            completionReason = "baggage_failed"
        } else if hotelReadinessSkipped {
            completionReason = "hotel_detail_readiness"
        } else if ref.bookingType == .hotel {
            completionReason = hotelDetailCompletionReason(stay: stay, details: details)
        } else {
            completionReason = nil
        }
        let completionResult: DiagnosticResult =
            (baggageSoftFailed || hotelReadinessSkipped) ? .skipped : .succeeded
        await recordDiagnosticPhase(
            "enrichment",
            event: "completed",
            result: completionResult,
            url: url,
            reason: completionReason
        )
        return enrichment
    }

    func check24StatusURL(from externalUrl: String) -> URL? {
        guard let url = URL(string: externalUrl) else { return nil }
        // Expected path:
        // /kundenbereich/<filekey>/<surname>
        guard let idx = url.pathComponents.firstIndex(of: "kundenbereich"),
              url.pathComponents.count > idx + 2
        else { return nil }

        let fileKey = url.pathComponents[idx + 1]
        let surname = url.pathComponents[idx + 2]

        let surnameEncoded = surname.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? surname

        return URL(string: "https://pbe.flug.check24.de/api/status/\(fileKey):\(surnameEncoded)")
    }
}
