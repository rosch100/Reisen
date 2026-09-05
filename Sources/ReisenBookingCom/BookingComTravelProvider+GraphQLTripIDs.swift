import Foundation
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    func fetchAllTripIDs(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens
    ) async throws -> [String] {
        var orderedIDs: [String] = []
        var seen = Set<String>()
        let parser = BookingComTripsGraphQLParser()

        for stages in BookingComGraphQLQueries.tripListStageGroups {
            let stageIDs = try await fetchTripIDsForStageGroup(
                stages: stages,
                using: webView,
                tokens: tokens,
                parser: parser,
                seen: &seen
            )
            orderedIDs.append(contentsOf: stageIDs)
        }

        return orderedIDs
    }
}
