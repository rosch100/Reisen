import Foundation
import ReisenDomain

@MainActor
extension BookingComTravelProvider {
    /// Trip-XP GraphQL: GetTrips → SingleTimeline pro Trip → Dedup.
    func fetchGraphQLCatalog(
        using webView: BookingComWebView,
        myTripsHTML: String,
        preferredTripIDs: [String]
    ) async throws -> [ProviderBookingDraft] {
        let tokens = try BookingComSessionTokens.extract(from: myTripsHTML)
        let tripIDs = await resolveTripIDs(preferredTripIDs: preferredTripIDs, using: webView, tokens: tokens)
        guard !tripIDs.isEmpty else { return [] }

        let result = await fetchTimelineCatalog(
            using: webView,
            tokens: tokens,
            tripIDs: tripIDs
        )
        return try finalizeTimelineCatalog(result, tripIDCount: tripIDs.count)
    }

    func finalizeTimelineCatalog(
        _ result: (bookings: [ProviderBookingDraft], timelineFailures: Int, lastTimelineError: Error?),
        tripIDCount: Int
    ) throws -> [ProviderBookingDraft] {
        if !result.bookings.isEmpty {
            return BookingComParsing.dedupeByExternalURL(result.bookings)
        }
        if result.timelineFailures == tripIDCount, let lastTimelineError = result.lastTimelineError {
            throw lastTimelineError
        }
        throw BookingComProviderError.catalogNotFound
    }
}
