import Foundation
import SwiftData

public enum ReisenMigrationPlan: SchemaMigrationPlan {
    /// Only the current schema is registered with SwiftData.
    /// Historical V1…V6 share the same `@Model` types as V7; listing them in a
    /// `SchemaMigrationPlan` produces "Duplicate version checksums" at runtime.
    /// The monolithic → hybrid store rewrite lives in
    /// `PersistenceBootstrap.migrateLegacyMonolithicStoreIfNeeded()`.
    public static var schemas: [any VersionedSchema.Type] {
        [ReisenSchemaV7.self]
    }

    public static var stages: [MigrationStage] {
        // Intentionally empty: VersionedSchema stages are not viable with shared model types.
        // Legacy store split is performed by `migrateLegacyMonolithicStoreIfNeeded()`.
        []
    }
}
