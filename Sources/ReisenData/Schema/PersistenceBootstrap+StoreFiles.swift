import Foundation

extension PersistenceBootstrap {
    public static func resetStoreFiles() throws {
        let fm = FileManager.default
        let urls = [
            try legacyStoreURL(),
            try cloudStoreURL(),
            try localStoreURL(),
        ]
        for url in urls {
            for candidate in sidecarURLs(for: url) where fm.fileExists(atPath: candidate.path) {
                try fm.removeItem(at: candidate)
            }
        }
    }
}
