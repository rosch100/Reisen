import Foundation
import SwiftData

/// V9 adds device-local `SDPreTravelHintLink` (EventKit mapping for pre-travel hints).
public enum ReisenSchemaV9: VersionedSchema {
    public static let versionIdentifier = Schema.Version(9, 0, 0)

    public static var cloudModels: [any PersistentModel.Type] {
        ReisenSchemaV8.cloudModels
    }

    public static var localModels: [any PersistentModel.Type] {
        ReisenSchemaV8.localModels + [SDPreTravelHintLink.self]
    }

    public static var models: [any PersistentModel.Type] {
        cloudModels + localModels
    }
}
