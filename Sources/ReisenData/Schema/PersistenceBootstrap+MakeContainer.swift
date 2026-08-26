import Foundation
import SwiftData

extension PersistenceBootstrap {
    public static func makeContainer(cloudKitEnabled: Bool? = nil) throws -> ModelContainer {
        let useCloudKit = cloudKitEnabled ?? isCloudKitEnabledByEnvironment()
        try migrateLegacyMonolithicStoreIfNeeded()

        do {
            return try openDualContainer(cloudKitEnabled: useCloudKit)
        } catch {
            // Incompatible leftover stores (e.g. failed VersionedSchema checksums) → wipe once and retry.
            try resetStoreFiles()
            do {
                return try openDualContainer(cloudKitEnabled: useCloudKit)
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
