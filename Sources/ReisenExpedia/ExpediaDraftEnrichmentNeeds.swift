import Foundation
import ReisenDomain

enum ExpediaDraftEnrichmentNeeds {
    /// Catalog leaves `confirmationCode` empty (Reiseplan ≠ Bestätigung).
    /// Re-enrich while price or hotel street address are still missing.
    /// Empty Ortszeit-deadlines alone must not re-trigger forever (TZ may be unresolvable).
    static func shouldEnrich(_ draft: ProviderBookingDraft, requiresDeadlines: Bool) -> Bool {
        _ = requiresDeadlines
        if draft.confirmationCode == nil { return true }
        if draft.rateDetails?.totalPriceAmount == nil { return true }
        if draft.bookingType == .hotel && draft.locationToAddress == nil { return true }
        return false
    }
}
