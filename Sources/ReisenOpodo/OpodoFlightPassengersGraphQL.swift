import Foundation
import ReisenDomain
import WebKit

/// Parses Opodo GraphQL responses for flight `travellers` and `baggageInfo`.
public enum OpodoFlightPassengersGraphQL {
    static let supportAreaGraphQLURL = URL(string: "https://www.opodo.de/support-area-bff/service/graphql")!

    public static func fetchPassengersAndBaggage(
        token: String,
        tripDetailsToken: String,
        using webView: WKWebView
    ) async throws -> [BookingPassenger] {
        let travellersBody = try getTripByTokenSupportAreaRequestBody(token: token)
        let travellersJSON = try await webView.fetchAuthenticatedText(
            url: supportAreaGraphQLURL,
            method: "POST",
            accept: "application/json",
            referer: "https://www.opodo.de/travel/secure/",
            contentType: "application/json",
            body: travellersBody
        )

        let passengers = try parseTravellers(from: travellersJSON)

        let baggageBody = try baggageInfoRequestBody(tripDetailsToken: tripDetailsToken)
        let baggageJSON = try await webView.fetchAuthenticatedText(
            url: supportAreaGraphQLURL,
            method: "POST",
            accept: "application/json",
            referer: "https://www.opodo.de/travel/secure/",
            contentType: "application/json",
            body: baggageBody
        )
        return try joinBaggage(from: passengers, baggageJSON: baggageJSON)
    }

    /// Test- & Debug-Entry: joint support-area `travellers` mit `baggageInfo` zu strukturierten Passagieren.
    public static func parsePassengersAndBaggage(travellersJSON: String, baggageJSON: String) throws -> [BookingPassenger] {
        let passengers = try parseTravellers(from: travellersJSON)
        return try joinBaggage(from: passengers, baggageJSON: baggageJSON)
    }
}
