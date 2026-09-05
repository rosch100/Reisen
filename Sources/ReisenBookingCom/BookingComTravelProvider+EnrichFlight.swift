import Foundation
import ReisenDomain
import ReisenProviders
import ReisenDiagnostics

@MainActor
extension BookingComTravelProvider {
    func enrichFlight(
        using webView: BookingComWebView,
        confirmationURL: URL
    ) async throws -> ProviderBookingEnrichment {
        guard let orderToken = Self.flightOrderToken(from: confirmationURL) else {
            recordFlightEnrichSkipped(reason: "missing_order_token")
            return emptyFlightEnrichment
        }

        onProgress?("Lade Flug-Stornooptionen…")

        guard let orderURL = flightOrderURL(orderToken: orderToken) else {
            recordFlightEnrichSkipped(reason: "missing_order_url")
            return emptyFlightEnrichment
        }

        guard let json = try await flightOrderJSON(
            using: webView,
            orderURL: orderURL,
            confirmationURL: confirmationURL
        ) else {
            recordFlightEnrichSkipped(reason: "order_fetch_failed")
            return emptyFlightEnrichment
        }

        guard let parsed = parseFlightOrder(json: json) else {
            recordFlightEnrichSkipped(reason: "order_parse_failed")
            return emptyFlightEnrichment
        }

        return DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .booking,
                bookingType: .flight,
                deadlines: parsed.deadlines,
                rateDetails: parsed.rateDetails,
                flightDepartureOffsetSeconds: parsed.flightDepartureOffsetSeconds,
                flightArrivalOffsetSeconds: parsed.flightArrivalOffsetSeconds,
                passengers: parsed.passengers
            )
        )
    }

    private var emptyFlightEnrichment: ProviderBookingEnrichment {
        DraftAssembler.enrichment(
            from: ProviderBookingFacts(provider: .booking, bookingType: .flight)
        )
    }

    func flightOrderURL(orderToken: String) -> URL? {
        var components = URLComponents(
            string: "https://flights.booking.com/api/order/\(orderToken)"
        )!
        components.queryItems = [
            URLQueryItem(name: "pb", value: "1"),
            URLQueryItem(name: "includeAvailableExtras", value: "1"),
            URLQueryItem(name: "cancellationOptionsType", value: "1"),
        ]
        return components.url
    }

    func flightOrderJSON(
        using webView: BookingComWebView,
        orderURL: URL,
        confirmationURL: URL
    ) async throws -> String? {
        do {
            return try await webView.fetchAuthenticatedText(
                url: orderURL,
                method: "GET",
                accept: "application/json, text/plain, */*",
                referer: confirmationURL.absoluteString,
                contentType: nil,
                body: nil,
                headers: [
                    "Origin": "https://flights.booking.com",
                ],
                timeoutSeconds: 60
            )
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw BookingComProviderError.sessionNotEstablished
        } catch {
            return nil
        }
    }

    func parseFlightOrder(json: String) -> BookingComFlightOrderParseResult? {
        do {
            return try BookingComFlightOrderParser().parse(from: json)
        } catch {
            return nil
        }
    }

    private func recordFlightEnrichSkipped(reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .booking,
                        operation: "booking_com_enrich_flight"
                    ),
                    component: "BookingComTravelProvider",
                    phase: "enrich_flight",
                    event: "flight_enrich_skipped",
                    result: .skipped,
                    reason: reason,
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
