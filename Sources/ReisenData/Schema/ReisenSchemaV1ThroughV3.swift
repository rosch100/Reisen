import Foundation
import SwiftData

public enum ReisenSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SDTrip.self,
            SDBooking.self,
            SDCancellationDeadline.self,
            SDBookingRateDetails.self,
            SDGap.self,
            SDReminder.self,
        ]
    }
}

public enum ReisenSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV1.models
    }
}

public enum ReisenSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV1.models + [
            SDBookingPassenger.self,
            SDBaggageAllowance.self,
        ]
    }
}
