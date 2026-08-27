import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

extension Check24TravelProvider {
    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        guard let url = URL(string: ref.externalUrl) else {
            throw Check24ProviderError.navigationFailed
        }
        try await load(url: url, in: webView)
        await dismissBookingChooserIfNeeded(
            in: webView,
            needles: [ref.externalUrl, url.lastPathComponent]
        )
        let snapshot = try await snapshotHTML(from: webView)
        let policy = CancellationPolicyParser().parseCancellationPolicy(from: snapshot.html)
        let details = BookingDetailsParser().parse(from: snapshot.html, bookingType: ref.bookingType)
        let stay = HotelCheckInOutParser().parse(from: snapshot.html)
        var passengers: [BookingPassenger]? = nil
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
                } catch {
                    passengers = nil
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
        return DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .check24,
                bookingType: ref.bookingType,
                deadlines: mappedDeadlines,
                rateDetails: rate,
                hotelCheckInMinutes: stay.checkInMinutes,
                hotelCheckOutMinutes: stay.checkOutMinutes,
                passengers: passengers ?? [],
                guestHints: hints
            )
        )
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
