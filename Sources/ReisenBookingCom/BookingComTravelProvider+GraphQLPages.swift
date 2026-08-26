import Foundation
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    func fetchTripIDsForStageGroup(
        stages: [String],
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        parser: BookingComTripsGraphQLParser,
        seen: inout Set<String>
    ) async -> [String] {
        var orderedIDs: [String] = []
        do {
            var paginationToken: String? = nil
            repeat {
                let page = try await fetchTripIDsPage(
                    using: webView,
                    tokens: tokens,
                    stages: stages,
                    paginationToken: paginationToken
                )
                appendUnseenTripIDs(page.tripIDs, into: &orderedIDs, seen: &seen)
                paginationToken = page.nextPaginationToken
            } while paginationToken != nil
        } catch {
            // Stage-Gruppe fehlgeschlagen → nächste / SSR-Fallback.
        }
        return orderedIDs
    }

    func appendUnseenTripIDs(
        _ tripIDs: [String],
        into orderedIDs: inout [String],
        seen: inout Set<String>
    ) {
        for id in tripIDs where !seen.contains(id) {
            seen.insert(id)
            orderedIDs.append(id)
        }
    }

    func fetchTripIDsPage(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        stages: [String],
        paginationToken: String?
    ) async throws -> (tripIDs: [String], nextPaginationToken: String?) {
        let json = try await fetchGetTripsGraphQL(
            using: webView,
            tokens: tokens,
            stages: stages,
            paginationToken: paginationToken
        )
        let parser = BookingComTripsGraphQLParser()
        let tripIDs = try parser.parseTripIDs(fromGetTripsJSON: json)
        let nextPaginationToken = try parser.parsePaginationToken(fromGetTripsJSON: json)
        return (tripIDs, nextPaginationToken)
    }
}
