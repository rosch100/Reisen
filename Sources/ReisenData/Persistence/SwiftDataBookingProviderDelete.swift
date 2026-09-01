import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataBookingProviderDelete {
    static func deleteProviderBookings(
        provider: ProviderID,
        keepingExternalURLs: Set<String>,
        from startOfDay: Date,
        in context: ModelContext
    ) throws {
        let models = try fetchProviderBookings(provider: provider, from: startOfDay, in: context)
        var affectedTripIDs = Set<UUID>()
        for model in models where shouldDelete(model, keepingExternalURLs: keepingExternalURLs) {
            if let tripID = model.trip?.id {
                affectedTripIDs.insert(tripID)
            }
            context.delete(model)
        }
        try AutoGapReconcileTrigger.run(tripIDs: affectedTripIDs, in: context)
    }
}
