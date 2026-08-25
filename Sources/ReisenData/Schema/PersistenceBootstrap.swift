import Foundation
import SwiftData

@MainActor
public enum PersistenceBootstrap {
    nonisolated public static let cloudKitContainerID = "iCloud.de.roschmac.Reisen"
    nonisolated public static let cloudStoreName = "reisen-cloud"
    nonisolated public static let localStoreName = "reisen-local"

    /// Non-versioned schema — `Schema(versionedSchema:)` + shared `@Model` types can abort with
    /// `Duplicate version checksums detected` (ObjC exception, not catchable as Swift Error).
    static func currentSchema() -> Schema {
        Schema(ReisenSchemaV8.models)
    }

    static func sidecarURLs(for url: URL) -> [URL] {
        [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal"),
        ]
    }
}
