import Foundation
import SwiftData

public enum ReisenSchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV3.models + [
            SDCalendarEventLink.self,
        ]
    }
}

public enum ReisenSchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV4.models + [
            SDBookingRoomItem.self,
        ]
    }
}

public enum ReisenSchemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV5.models + [
            SDCancellationDeadlineLink.self,
        ]
    }
}
