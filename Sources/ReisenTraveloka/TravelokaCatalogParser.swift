import Foundation
import ReisenDomain

public enum TravelokaCatalogParser {
    public static func parse(from responseText: String) throws -> ProviderCatalog {
        let entries = try TravelokaJSON.itineraryEntries(from: responseText)
        let drafts = try entries.map { try TravelokaItineraryEntryParser.draft(from: $0) }
        return ProviderCatalog(bookings: drafts)
    }
}
