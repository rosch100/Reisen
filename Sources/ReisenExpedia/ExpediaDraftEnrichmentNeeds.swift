import Foundation
import ReisenDomain

enum ExpediaDraftEnrichmentNeeds {
    /// Catalog leaves `confirmationCode` empty (Reiseplan ≠ Bestätigung). Enrich once for real codes/details.
    /// Missing hotel cancel URL / price / Ortszeit-deadlines must not re-trigger forever.
    static func shouldEnrich(_ draft: ProviderBookingDraft, requiresDeadlines: Bool) -> Bool {
        _ = requiresDeadlines
        return draft.confirmationCode == nil
    }
}
