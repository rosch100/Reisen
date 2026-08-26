import Foundation
import ReisenDomain
import ReisenProviders

public enum TravelokaCatalogParser {
    public static func parse(
        from responseText: String,
        routePrefix: String = TravelokaWebConstants.routePrefix
    ) throws -> ProviderCatalog {
        let entries = try TravelokaJSON.itineraryEntries(from: responseText)
        let drafts = try entries.map {
            try TravelokaItineraryEntryParser.draft(from: $0, routePrefix: routePrefix)
        }
        return ProviderCatalog(bookings: drafts)
    }
}
