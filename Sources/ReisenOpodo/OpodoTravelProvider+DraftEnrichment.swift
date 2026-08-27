import ReisenDomain
import ReisenProviders

extension OpodoTravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        // Opodo braucht pro URL einen Status-Probe; unabhängig von Stornofrist-Einstellungen.
        needsDraftEnrichmentForExternalURL(draft: draft, requiresDeadlines: requiresDeadlines)
    }
}
