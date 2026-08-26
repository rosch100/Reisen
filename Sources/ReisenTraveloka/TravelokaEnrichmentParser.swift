import Foundation
import ReisenDomain

public enum TravelokaEnrichmentParser {
    public static func parse(from responseText: String) throws -> ProviderBookingEnrichment {
        let entry = try TravelokaJSON.firstItineraryEntry(from: responseText)
        return try TravelokaItineraryEntryParser.enrichment(from: entry)
    }

    /// IANA aus Catalog/Detail (`ianaTimezoneBegin`), für Refund-Fristen ohne GMT-Offset-Hack.
    public static func timeZoneIdentifier(from responseText: String) -> String? {
        guard let entry = try? TravelokaJSON.firstItineraryEntry(from: responseText) else {
            return nil
        }
        let common = TravelokaJSON.commonSummary(from: entry)
        return TravelokaJSON.string(common["ianaTimezoneBegin"])
            ?? TravelokaJSON.string(common["ianaTimezoneEnd"])
    }
}
