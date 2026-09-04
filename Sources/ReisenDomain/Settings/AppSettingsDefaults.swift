import Foundation

/// Prozessweite UserDefaults-Quelle für Settings-Lookups (SSOT).
/// UITesting setzt Override auf die Isolated-Suite — sonst lesen Registry/Sync `.standard`
/// während AppStorage die Isolated-Suite nutzt.
public enum AppSettingsDefaults: Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var overrideDefaults: UserDefaults?

    public static var current: UserDefaults {
        lock.lock()
        defer { lock.unlock() }
        return overrideDefaults ?? .standard
    }

    public static func installOverride(_ defaults: UserDefaults?) {
        lock.lock()
        overrideDefaults = defaults
        lock.unlock()
    }
}
