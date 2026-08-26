import Foundation
import SwiftData
import ReisenDomain

/// In-place upsert of deadlines by `id`, then content key (avoids CloudKit tombstones).
enum SwiftDataBookingDeadlineUpsert {
    static func upsert(_ deadlines: [CancellationDeadline], on model: SDBooking, in context: ModelContext) {
        var remaining = model.cancellationDeadlines ?? []
        var kept: [SDCancellationDeadline] = []

        for deadline in deadlines {
            let row = takeOrCreate(deadline, from: &remaining, booking: model, in: context)
            apply(deadline, to: row, booking: model)
            kept.append(row)
        }

        SwiftDataBookingMatchHelpers.deleteAll(remaining, in: context)
        model.cancellationDeadlines = kept
    }
}
