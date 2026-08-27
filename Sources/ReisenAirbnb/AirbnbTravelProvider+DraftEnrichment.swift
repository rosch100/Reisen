import ReisenDomain
import ReisenProviders

extension AirbnbTravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        // Airbnb liefert Adressen/Check-in oft erst auf der Detailseite.
        needsEveryCatalogDraftEnrichment(draft: draft, requiresDeadlines: requiresDeadlines)
    }
}
