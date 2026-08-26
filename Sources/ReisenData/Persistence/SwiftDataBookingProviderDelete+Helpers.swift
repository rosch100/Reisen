import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingProviderDelete {
    static func fetchProviderBookings(
        provider: ProviderID,
        from startOfDay: Date,
        in context: ModelContext
    ) throws -> [SDBooking] {
        let providerRaw = provider.rawValue
        let descriptor = FetchDescriptor<SDBooking>(
            predicate: #Predicate<SDBooking> {
                $0.providerRaw == providerRaw && $0.startAt >= startOfDay
            }
        )
        return try context.fetch(descriptor)
    }

    static func shouldDelete(_ model: SDBooking, keepingExternalURLs: Set<String>) -> Bool {
        guard let url = model.externalUrl else { return true }
        return !keepingExternalURLs.contains(url)
    }
}
