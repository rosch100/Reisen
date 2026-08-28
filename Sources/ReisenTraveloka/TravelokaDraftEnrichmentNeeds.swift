import ReisenDomain

/// Traveloka-specific enrichment gate (beyond shared `DraftEnrichmentNeeds`).
enum TravelokaDraftEnrichmentNeeds {
    static func shouldEnrich(
        _ draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        if DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: requiresDeadlines) {
            return true
        }
        // Catalog cards can be field-complete without stay policies (`single` has them).
        // Sync overwrites `booking.guestHints` from the draft — skip enrich ⇒ hints vanish.
        return draft.bookingType == .hotel && draft.guestHints.isEmpty
    }
}
