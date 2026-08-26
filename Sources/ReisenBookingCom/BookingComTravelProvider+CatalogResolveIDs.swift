import Foundation

@MainActor
extension BookingComTravelProvider {
    func resolveTripIDs(
        preferredTripIDs: [String],
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens
    ) async -> [String] {
        let tripIDs = await fetchAllTripIDs(using: webView, tokens: tokens)
        if tripIDs.isEmpty {
            return preferredTripIDs
        }

        // SSR-Upcoming zuerst, dann Rest aus GetTrips (ohne Duplikate).
        var ordered = preferredTripIDs
        var seen = Set(preferredTripIDs)
        for id in tripIDs where !seen.contains(id) {
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }
}
