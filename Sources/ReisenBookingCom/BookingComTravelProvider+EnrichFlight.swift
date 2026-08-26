import Foundation
import ReisenDomain
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    func enrichFlight(
        using webView: BookingComWebView,
        confirmationURL: URL
    ) async throws -> ProviderBookingEnrichment {
        guard let orderToken = Self.flightOrderToken(from: confirmationURL) else {
            return ProviderBookingEnrichment()
        }

        onProgress?("Lade Flug-Stornooptionen…")

        guard let orderURL = flightOrderURL(orderToken: orderToken) else {
            return ProviderBookingEnrichment()
        }

        guard let json = try await flightOrderJSON(
            using: webView,
            orderURL: orderURL,
            confirmationURL: confirmationURL
        ) else {
            return ProviderBookingEnrichment()
        }

        guard let parsed = parseFlightOrder(json: json) else {
            return ProviderBookingEnrichment()
        }

        return ProviderBookingEnrichment(
            deadlines: parsed.deadlines,
            rateDetails: parsed.rateDetails,
            passengers: parsed.passengers.isEmpty ? nil : parsed.passengers,
            flightDepartureOffsetSeconds: parsed.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: parsed.flightArrivalOffsetSeconds
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
                ]
            )
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
}
