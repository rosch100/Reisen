import ReisenDomain
import ReisenProviders

extension GetYourGuideTravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        // Treffpunkt/Teilnehmer fehlen oft im Katalog; Enrichment pro Buchungs-URL.
        needsEveryCatalogDraftEnrichment(draft: draft, requiresDeadlines: requiresDeadlines)
    }
}
