import Foundation
import ReisenDomain

@MainActor
extension BookingComTravelProvider {
    func fetchTimelineCatalog(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        tripIDs: [String]
    ) async -> (bookings: [ProviderBookingDraft], timelineFailures: Int, lastTimelineError: Error?) {
        var bookings: [ProviderBookingDraft] = []
        var timelineFailures = 0
        var lastTimelineError: Error?

        for (index, tripID) in tripIDs.enumerated() {
            onProgress?("Lade Trip-Details \(index + 1)/\(tripIDs.count)…")
            do {
                let drafts = try await fetchTimelineDrafts(
                    using: webView,
                    tokens: tokens,
                    tripID: tripID
                )
                bookings.append(contentsOf: drafts)
            } catch {
                lastTimelineError = error
                timelineFailures += 1
            }
        }

        return (bookings, timelineFailures, lastTimelineError)
    }

    func fetchTimelineDrafts(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        tripID: String
    ) async throws -> [ProviderBookingDraft] {
        let timelineJSON = try await fetchTimelineGraphQL(
            using: webView,
            tokens: tokens,
            tripID: tripID
        )
        return try BookingComTripsGraphQLParser().parseTimeline(from: timelineJSON)
    }
}
