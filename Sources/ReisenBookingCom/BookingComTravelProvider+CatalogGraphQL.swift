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
        let tripIDs = try await resolveTripIDs(preferredTripIDs: preferredTripIDs, using: webView, tokens: tokens)
        guard !tripIDs.isEmpty else { return [] }

        let result = try await fetchTimelineCatalog(
            using: webView,
            tokens: tokens,
            tripIDs: tripIDs
        )
        return try finalizeTimelineCatalog(result)
    }

    func finalizeTimelineCatalog(
        _ result: (bookings: [ProviderBookingDraft], timelineFailures: Int, lastTimelineError: Error?)
    ) throws -> [ProviderBookingDraft] {
        if result.timelineFailures > 0 {
            if let lastTimelineError = result.lastTimelineError {
                throw lastTimelineError
            }
            throw BookingComProviderError.catalogNotFound
        }
        if !result.bookings.isEmpty {
            return BookingComParsing.dedupeByExternalURL(result.bookings)
        }
        throw BookingComProviderError.catalogNotFound
    }
}
