import Foundation
import ReisenDomain

/// One page or the aggregated `getTrips` catalog. HTML only when GraphQL returned zero trip rows.
public struct OpodoGraphQLCatalog: Sendable {
    public let bookings: [ProviderBookingDraft]
    public let rawTripCount: Int

    public init(bookings: [ProviderBookingDraft], rawTripCount: Int) {
        self.bookings = ProviderCatalog(bookings: bookings).dedupedByExternalURL().bookings
        self.rawTripCount = rawTripCount
    }

    public var needsHTMLFallback: Bool {
        bookings.isEmpty && rawTripCount == 0
    }

    public func resolved(htmlFallback: [ProviderBookingDraft] = []) -> ProviderCatalog {
        if needsHTMLFallback {
            return ProviderCatalog(bookings: htmlFallback)
        }
        return ProviderCatalog(bookings: bookings)
    }
}
