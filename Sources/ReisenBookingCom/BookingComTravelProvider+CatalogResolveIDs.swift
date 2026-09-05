import Foundation

/// Pure ordering for catalog trip IDs: HTML preferred ∩ GetTrips active, then rest of GetTrips.
enum BookingComTripIDOrdering {
    /// Prefer HTML order for IDs still present in the active GetTrips set, then append remaining GetTrips IDs.
    /// Caller must keep the empty-GetTrips fallback (`return preferred`) outside this merge.
    static func mergePreferredTripIDs(_ preferred: [String], withActiveGetTrips active: [String]) -> [String] {
        let activeSet = Set(active)
        var ordered: [String] = []
        var seen = Set<String>()
        for id in preferred where activeSet.contains(id) {
            guard seen.insert(id).inserted else { continue }
            ordered.append(id)
        }
        for id in active where !seen.contains(id) {
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }
}

@MainActor
extension BookingComTravelProvider {
    func resolveTripIDs(
        preferredTripIDs: [String],
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens
    ) async throws -> [String] {
        let tripIDs = try await fetchAllTripIDs(using: webView, tokens: tokens)
        if tripIDs.isEmpty {
            return preferredTripIDs
        }

        // GetTrips (ohne canceled) ist die Aktivmenge: preferred HTML nur behalten, wenn noch aktiv.
        return BookingComTripIDOrdering.mergePreferredTripIDs(
            preferredTripIDs,
            withActiveGetTrips: tripIDs
        )
    }
}
