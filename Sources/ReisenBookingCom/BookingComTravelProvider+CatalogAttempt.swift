import Foundation
import ReisenDomain

@MainActor
extension BookingComTravelProvider {
    func attemptGraphQLCatalog(
        using webView: BookingComWebView,
        myTripsHTML: String,
        preferredTripIDs: [String]
    ) async -> GraphQLAttemptResult {
        do {
            let bookings = try await fetchGraphQLCatalog(
                using: webView,
                myTripsHTML: myTripsHTML,
                preferredTripIDs: preferredTripIDs
            )
            return bookings.isEmpty ? .empty : .bookings(bookings)
        } catch {
            return .error(error)
        }
    }
}
