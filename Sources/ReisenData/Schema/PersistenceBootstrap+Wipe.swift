import Foundation
import SwiftData

extension PersistenceBootstrap {
    /// Deletes all syncable (cloud-store) entities so CloudKit can propagate removals.
    /// Device-local EventKit/Reminder links are left untouched unless `includeLocal` is true.
    public static func wipeSyncedEntities(
        in context: ModelContext,
        includeLocal: Bool = false
    ) throws {
        try deleteAll(SDTrip.self, in: context)
        try deleteAll(SDBooking.self, in: context)
        try deleteAll(SDGap.self, in: context)
        try deleteAll(SDCancellationDeadline.self, in: context)
        try deleteAll(SDBookingRateDetails.self, in: context)
        try deleteAll(SDBookingRoomItem.self, in: context)
        try deleteAll(SDBookingPassenger.self, in: context)
        try deleteAll(SDBaggageAllowance.self, in: context)

        if includeLocal {
            try deleteAll(SDReminder.self, in: context)
            try deleteAll(SDCalendarEventLink.self, in: context)
            try deleteAll(SDCancellationDeadlineLink.self, in: context)
        }

        try context.save()
    }

    static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let models = try context.fetch(FetchDescriptor<T>())
        for model in models {
            context.delete(model)
        }
    }
}
