import Foundation
import SwiftData

/// V11 adds cloud `SDProviderPreferences` (provider enablement + setupCompleted mirror).
public enum ReisenSchemaV11: VersionedSchema {
    public static let versionIdentifier = Schema.Version(11, 0, 0)

    public static var cloudModels: [any PersistentModel.Type] {
        ReisenSchemaV10.cloudModels + [SDProviderPreferences.self]
    }

    public static var localModels: [any PersistentModel.Type] {
        ReisenSchemaV10.localModels
    }

    public static var models: [any PersistentModel.Type] {
        cloudModels + localModels
    }
}
