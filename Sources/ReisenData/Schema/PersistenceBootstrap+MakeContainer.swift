import Foundation
import SwiftData

extension PersistenceBootstrap {
    public static func makeContainer(cloudKitEnabled: Bool) throws -> ModelContainer {
        try migrateLegacyMonolithicStoreIfNeeded()

        do {
            return try openDualContainer(cloudKitEnabled: cloudKitEnabled)
        } catch {
            // Incompatible leftover stores (e.g. failed VersionedSchema checksums) → wipe once and retry.
            try resetStoreFiles()
            do {
                return try openDualContainer(cloudKitEnabled: cloudKitEnabled)
            } catch {
                throw PersistenceStoreError.storeIncompatible(String(describing: error))
            }
        }
    }

    /// In-memory dual-store container for unit tests (CloudKit always off).
    public static func makeInMemoryContainer() throws -> ModelContainer {
        try openDualContainer(cloudKitEnabled: false, inMemory: true)
    }

    /// Dual-store container at explicit URLs (for two-device sync contract tests; CloudKit off).
    public static func makeDualContainer(
        cloudStoreURL: URL,
        localStoreURL: URL
    ) throws -> ModelContainer {
        try openDualContainer(
            cloudKitEnabled: false,
            cloudURL: cloudStoreURL,
            localURL: localStoreURL
        )
    }
}
