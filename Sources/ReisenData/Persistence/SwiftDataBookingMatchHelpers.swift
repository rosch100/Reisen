import Foundation
import SwiftData

/// In-place identity matching and batch delete for booking child upserts.
enum SwiftDataBookingMatchHelpers {
    /// Prefer stable `id`, then content-key match — keeps CloudKit identities across syncs.
    static func takeMatching<T>(
        from remaining: inout [T],
        id: UUID,
        idOf: KeyPath<T, UUID>,
        contentMatch: (T) -> Bool
    ) -> T? {
        if let index = remaining.firstIndex(where: { $0[keyPath: idOf] == id }) {
            return remaining.remove(at: index)
        }
        if let index = remaining.firstIndex(where: contentMatch) {
            return remaining.remove(at: index)
        }
        return nil
    }

    static func deleteAll<T: PersistentModel>(_ models: [T], in context: ModelContext) {
        for model in models {
            context.delete(model)
        }
    }
}
