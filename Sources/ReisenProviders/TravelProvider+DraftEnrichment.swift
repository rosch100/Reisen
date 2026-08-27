import Foundation
import ReisenDomain

extension TravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        draft.needsDeadlineEnrichment(requiresDeadlines: requiresDeadlines)
    }

    /// Detailseiten-Enrichment für jeden Katalog-Draft (unabhängig von Typ/Fristen).
    public func needsEveryCatalogDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        _ = draft
        _ = requiresDeadlines
        return true
    }

    /// Enrichment sobald eine Buchungs-URL vorhanden ist (z. B. Opodo-Status-Probe).
    public func needsDraftEnrichmentForExternalURL(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        _ = requiresDeadlines
        return draft.externalUrl != nil
    }
}
