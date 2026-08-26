import Foundation
import SwiftData

extension PersistenceBootstrap {
    /// One-time copy from pre-V7 `ReisenData.sqlite` into cloud/local stores.
    static func migrateLegacyMonolithicStoreIfNeeded() throws {
        let fm = FileManager.default
        let legacyURL = try legacyStoreURL()
        guard fm.fileExists(atPath: legacyURL.path) else { return }

        let cloudURL = try cloudStoreURL()
        let localURL = try localStoreURL()
        if fm.fileExists(atPath: cloudURL.path) || fm.fileExists(atPath: localURL.path) {
            // New stores already present — drop leftover legacy file only.
            for candidate in sidecarURLs(for: legacyURL) where fm.fileExists(atPath: candidate.path) {
                try fm.removeItem(at: candidate)
            }
            return
        }

        // Open legacy file with current model types (no VersionedSchema — avoids checksum crashes).
        let legacySchema = currentSchema()
        let legacyConfig = ModelConfiguration(
            schema: legacySchema,
            url: legacyURL,
            cloudKitDatabase: .none
        )
        let legacyContainer: ModelContainer
        do {
            legacyContainer = try ModelContainer(for: legacySchema, configurations: [legacyConfig])
        } catch {
            // Unreadable legacy store — drop it; caller continues with empty hybrid stores.
            for candidate in sidecarURLs(for: legacyURL) where fm.fileExists(atPath: candidate.path) {
                try fm.removeItem(at: candidate)
            }
            return
        }
        let legacyContext = ModelContext(legacyContainer)

        let target = try openDualContainer(cloudKitEnabled: false)
        let targetContext = ModelContext(target)

        try copyCloudEntities(from: legacyContext, to: targetContext)
        try copyLocalEntities(from: legacyContext, to: targetContext)
        try targetContext.save()

        // Drop ModelContainer references before deleting files.
        for candidate in sidecarURLs(for: legacyURL) where fm.fileExists(atPath: candidate.path) {
            try fm.removeItem(at: candidate)
        }
    }
}
