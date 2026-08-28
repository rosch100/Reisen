import Foundation
import ReisenDomain
import WebKit

/// Parses Opodo GraphQL responses for flight `travellers` and `baggageInfo`.
public enum OpodoFlightPassengersGraphQL {
    static let supportAreaGraphQLURL = URL(string: OpodoWeb.origin + "/support-area-bff/service/graphql")!

    public static func fetchPassengersAndBaggage(
        token: String,
        using webView: WKWebView
    ) async throws -> [BookingPassenger] {
        let travellersBody = try getTripByTokenSupportAreaRequestBody(token: token)
        let travellersJSON = try await postSupportAreaGraphQL(using: webView, body: travellersBody)
        let passengers = try parseTravellers(from: travellersJSON)

        let baggageBody = try baggageInfoRequestBody(tripDetailsToken: token)
        let baggageJSON = try await postSupportAreaGraphQL(using: webView, body: baggageBody)
        return try joinBaggage(from: passengers, baggageJSON: baggageJSON)
    }

    private static func postSupportAreaGraphQL(using webView: WKWebView, body: Data) async throws -> String {
        try await webView.fetchAuthenticatedText(
            url: supportAreaGraphQLURL,
            method: "POST",
            accept: "application/json",
            referer: OpodoWeb.secureAreaURLString,
            contentType: "application/json",
            body: body
        )
    }

    /// Test- & Debug-Entry: joint support-area `travellers` mit `baggageInfo` zu strukturierten Passagieren.
    public static func parsePassengersAndBaggage(travellersJSON: String, baggageJSON: String) throws -> [BookingPassenger] {
        let passengers = try parseTravellers(from: travellersJSON)
        return try joinBaggage(from: passengers, baggageJSON: baggageJSON)
    }
}
