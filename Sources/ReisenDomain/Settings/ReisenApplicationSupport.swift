import Foundation

/// SSOT für das Application-Support-Verzeichnis der App (`…/Application Support/Reisen`).
public enum ReisenApplicationSupport {
    public static func directoryURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Reisen", isDirectory: true)
    }
}
