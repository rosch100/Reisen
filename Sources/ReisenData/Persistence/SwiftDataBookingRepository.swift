import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataBookingRepository: BookingRepository {
    let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
