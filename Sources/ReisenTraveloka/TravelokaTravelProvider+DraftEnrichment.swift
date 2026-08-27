import ReisenDomain
import ReisenProviders

extension TravelokaTravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        TravelokaEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: requiresDeadlines)
    }
}
