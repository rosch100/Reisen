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
        for model in models where shouldDelete(model, keepingExternalURLs: keepingExternalURLs) {
            context.delete(model)
        }
    }
}
