import Foundation

extension ProviderCatalog {
    public func dedupedByExternalURL() -> ProviderCatalog {
        var byURL: [String: ProviderBookingDraft] = [:]
        for booking in bookings {
            guard let url = booking.externalUrl else { continue }
            byURL[url] = booking
        }
        return ProviderCatalog(
            bookings: Array(byURL.values).sorted { $0.startAt < $1.startAt }
        )
    }
}
