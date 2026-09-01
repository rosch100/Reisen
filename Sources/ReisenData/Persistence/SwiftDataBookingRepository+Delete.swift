import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingRepository {
    public func delete(id: UUID) throws {
        guard let model = try SwiftDataBookingFind.byID(id, in: modelContext) else {
            throw RepositoryError.notFound("Booking \(id)")
        }
        let tripID = model.trip?.id
        if model.provider == .autoGap,
           let tripID,
           let key = model.autoGapIdentityKey,
           !key.isEmpty
        {
            try SwiftDataAutoGapReconciler.suppress(tripID: tripID, identityKey: key, in: modelContext)
        }
        modelContext.delete(model)
        if let tripID {
            try AutoGapReconcileTrigger.run(tripIDs: [tripID], in: modelContext)
        }
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
