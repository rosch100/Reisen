import Foundation
import ReisenDomain
import ReisenProviders

public enum TravelokaCatalogParser {
    public static func parse(
        from responseText: String,
        routePrefix: String = TravelokaWebConstants.routePrefix
    ) throws -> ProviderCatalog {
        let entries = try TravelokaJSON.itineraryEntries(from: responseText)
        var drafts: [ProviderBookingDraft] = []
        for entry in entries {
            if let draft = try TravelokaItineraryEntryParser.draft(from: entry, routePrefix: routePrefix) {
                drafts.append(draft)
            }
        }
        return ProviderCatalog(bookings: drafts)
    }
}
