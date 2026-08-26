import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingRepository {
    public func delete(id: UUID) throws {
        guard let model = try SwiftDataBookingFind.byID(id, in: modelContext) else {
            throw RepositoryError.notFound("Booking \(id)")
        }
        modelContext.delete(model)
    }

    public func deleteProviderBookings(
        provider: ProviderID,
        keepingExternalURLs: Set<String>,
        from startOfDay: Date
    ) throws {
        try SwiftDataBookingProviderDelete.deleteProviderBookings(
            provider: provider,
            keepingExternalURLs: keepingExternalURLs,
            from: startOfDay,
            in: modelContext
        )
    }
}
