import Foundation
import ReisenDomain

@MainActor
extension BookingComTravelProvider {
    func fetchCatalogFallbackHTML(
        htmlTripIDs: [String],
        myTripsHTML: String
    ) throws -> CatalogFallbackResult {
        // Marketing-Copy ist kein Empty-Signal (HAR). Ohne trip_id= und ohne Card-HTML → leer.
        if htmlTripIDs.isEmpty {
            return try fetchCatalogFallbackHTMLWhenTripIDsEmpty(myTripsHTML: myTripsHTML)
        }
        return fetchCatalogFallbackHTMLWhenTripIDsNotEmpty(myTripsHTML: myTripsHTML)
    }
}
