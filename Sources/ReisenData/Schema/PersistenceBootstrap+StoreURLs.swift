import Foundation

extension PersistenceBootstrap {
    nonisolated public static func supportDirectoryURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Reisen", isDirectory: true)
    }

    public static func supportDirectory() throws -> URL {
        let fm = FileManager.default
        guard let base = supportDirectoryURL() else {
            throw PersistenceStoreError.containerCreationFailed("Application Support Verzeichnis fehlt.")
        }
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Legacy single-file store (pre V7 hybrid).
    public static func legacyStoreURL() throws -> URL {
        try supportDirectory().appendingPathComponent("ReisenData.sqlite", isDirectory: false)
    }

    public static func cloudStoreURL() throws -> URL {
        try supportDirectory().appendingPathComponent("ReisenCloud.sqlite", isDirectory: false)
    }

    public static func localStoreURL() throws -> URL {
        try supportDirectory().appendingPathComponent("ReisenLocal.sqlite", isDirectory: false)
    }

    /// Backwards-compatible alias for callers/tests expecting a single store URL.
    public static func storeURL() throws -> URL {
        try cloudStoreURL()
    }
}
