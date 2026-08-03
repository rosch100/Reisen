import Foundation
import ReisenDomain

@MainActor
extension BookingComTravelProvider {
    func fetchCatalogFallbackHTMLWhenTripIDsEmpty(
        myTripsHTML: String
    ) throws -> CatalogFallbackResult {
        do {
            let bookings = try BookingComActivityListParser().parseBookings(from: myTripsHTML)
            return .bookings(bookings)
        } catch is BookingComActivityListParserError {
            return .bookings([])
        }
    }

    func fetchCatalogFallbackHTMLWhenTripIDsNotEmpty(
        myTripsHTML: String
    ) -> CatalogFallbackResult {
        do {
            let bookings = try BookingComActivityListParser().parseBookings(from: myTripsHTML)
            guard !bookings.isEmpty else { return .none }
            return .bookings(bookings)
        } catch {
            // trip_id vorhanden, Card-HTML nicht parsebar
            return .none
        }
    }
}
