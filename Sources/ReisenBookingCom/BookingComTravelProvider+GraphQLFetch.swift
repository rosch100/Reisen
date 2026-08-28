import Foundation
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    func fetchGetTripsGraphQL(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        stages: [String],
        paginationToken: String?
    ) async throws -> String {
        // HAR: rowsPerPage 10, headerSize 672×378 für Trip-Karten.
        var pagination: [String: Any] = ["rowsPerPage": 10]
        if let paginationToken {
            pagination["paginationToken"] = paginationToken
        } else {
            pagination["paginationToken"] = NSNull()
        }
        let variables: [String: Any] = [
            "input": [
                "stages": stages,
                "pagination": pagination,
                "headerSize": [["width": 672, "height": 378]],
            ],
        ]
        return try await postGraphQL(
            using: webView,
            tokens: tokens,
            operationName: "GetTripsQuery",
            query: BookingComGraphQLQueries.getTripsQuery,
            variables: variables
        )
    }

    func fetchTimelineGraphQL(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        tripID: String
    ) async throws -> String {
        // MFE 2026-08: Live-Connector-/Experience-Listen + Thumbnail-Größe.
        let variables: [String: Any] = [
            "input": [
                "tripId": tripID,
                "thumbnailSize": ["width": 2192, "height": 548],
                "selectConnectorChannels": ["MY_TRIPS_TIMELINE"],
                "supportedConnectors": BookingComGraphQLQueries.timelineSupportedConnectors,
                "supportedExperiences": BookingComGraphQLQueries.timelineSupportedExperiences,
            ],
        ]
        return try await postGraphQL(
            using: webView,
            tokens: tokens,
            operationName: "SingleTimelineQuery",
            query: BookingComGraphQLQueries.singleTimelineQuery,
            variables: variables
        )
    }
}
