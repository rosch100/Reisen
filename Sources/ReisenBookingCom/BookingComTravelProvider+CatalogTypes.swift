import Foundation
import ReisenDomain
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    enum CatalogFallbackResult {
        case bookings([ProviderBookingDraft])
        case none
    }

    enum GraphQLAttemptResult {
        case bookings([ProviderBookingDraft])
        case empty
        case error(Error)
    }
}
