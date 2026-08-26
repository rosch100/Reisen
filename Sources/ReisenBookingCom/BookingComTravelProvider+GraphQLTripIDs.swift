import Foundation
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    func fetchAllTripIDs(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens
    ) async -> [String] {
        var orderedIDs: [String] = []
        var seen = Set<String>()
        let parser = BookingComTripsGraphQLParser()

        for stages in BookingComGraphQLQueries.tripListStageGroups {
            let stageIDs = await fetchTripIDsForStageGroup(
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
