import Foundation
import SwiftData

/// CloudKit-ready schema: defaults on required attributes, complete inverses,
/// Reminder soft-refs (UUID) so device-local alarm IDs stay out of CloudKit.
public enum ReisenSchemaV8: VersionedSchema {
    public static let versionIdentifier = Schema.Version(8, 0, 0)

    public static var cloudModels: [any PersistentModel.Type] {
        [
            SDTrip.self,
            SDBooking.self,
            SDCancellationDeadline.self,
            SDBookingRateDetails.self,
            SDBookingRoomItem.self,
            SDBookingPassenger.self,
            SDBaggageAllowance.self,
            SDBookingGuestHint.self,
            SDGap.self,
        ]
    }

    public static var localModels: [any PersistentModel.Type] {
        [
            SDReminder.self,
            SDCalendarEventLink.self,
            SDCancellationDeadlineLink.self,
        ]
    }

    public static var models: [any PersistentModel.Type] {
        cloudModels + localModels
    }
}
