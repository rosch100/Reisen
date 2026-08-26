import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingRepository {
    public func fetchAll() throws -> [Booking] {
        try modelContext.fetch(FetchDescriptor<SDBooking>()).map(DomainMapper.booking(from:))
    }

    public func fetch(id: UUID) throws -> Booking? {
        try SwiftDataBookingFind.byID(id, in: modelContext).map(DomainMapper.booking(from:))
    }

    public func fetch(provider: ProviderID, from startOfDay: Date) throws -> [Booking] {
        let providerRaw = provider.rawValue
        let descriptor = FetchDescriptor<SDBooking>(
            predicate: #Predicate<SDBooking> {
                $0.providerRaw == providerRaw && $0.startAt >= startOfDay
            }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.booking(from:))
    }
}
