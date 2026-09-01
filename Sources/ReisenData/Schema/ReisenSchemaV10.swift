import Foundation
import SwiftData

/// V10 adds cloud `SDAutoGapSuppress` (per-trip auto-gap dismiss keys).
public enum ReisenSchemaV10: VersionedSchema {
    public static let versionIdentifier = Schema.Version(10, 0, 0)

    public static var cloudModels: [any PersistentModel.Type] {
        ReisenSchemaV9.cloudModels + [SDAutoGapSuppress.self]
    }

    public static var localModels: [any PersistentModel.Type] {
        ReisenSchemaV9.localModels
    }

    public static var models: [any PersistentModel.Type] {
        cloudModels + localModels
    }
}
