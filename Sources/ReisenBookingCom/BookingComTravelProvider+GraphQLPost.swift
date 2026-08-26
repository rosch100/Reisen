import Foundation
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    func postGraphQL(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        operationName: String,
        query: String,
        variables: [String: Any]
    ) async throws -> String {
        let bodyObject: [String: Any] = [
            "operationName": operationName,
            "variables": variables,
            "query": query,
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyObject)
        let headers = graphQLHeaders(tokens: tokens)

        // Primär: In-Page-fetch (HAR/WAF/Cookies im Browser-Kontext).
        do {
            return try await webView.fetchInPageText(
                url: BookingComGraphQLQueries.graphqlURL,
                method: "POST",
                headers: headers,
                body: body
            )
        } catch {
            return try await webView.fetchAuthenticatedText(
                url: BookingComGraphQLQueries.graphqlURL,
                method: "POST",
                accept: "*/*",
                referer: Self.myTripsURL.absoluteString,
                contentType: "application/json",
                body: body,
                headers: headers
            )
        }
    }

    func graphQLHeaders(tokens: BookingComSessionTokens) -> [String: String] {
        [
            "Accept": "*/*",
            "Content-Type": "application/json",
            "Origin": "https://secure.booking.com",
            "x-booking-csrf-token": tokens.csrfToken,
            "apollographql-client-name": BookingComGraphQLQueries.apolloClientName,
            "apollographql-client-version": tokens.apolloClientVersion,
            "x-booking-site-type-id": "1",
            "x-booking-topic": "capla_browser_b-trips-frontend-trip-xp-mfe",
            "x-booking-context-action": "mytrips",
            "x-booking-context-action-name": "mytrips",
        ]
    }
}
