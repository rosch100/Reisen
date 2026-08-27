import ReisenDomain
import ReisenProviders

extension BookingComTravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        // Booking.com verfeinert Details/Stornofristen auf Detailseiten für alle Katalog-Typen.
        needsEveryCatalogDraftEnrichment(draft: draft, requiresDeadlines: requiresDeadlines)
    }
}
