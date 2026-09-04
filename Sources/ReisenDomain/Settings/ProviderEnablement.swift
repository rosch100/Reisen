import Foundation

/// Persistiert Provider-Aktivierung (opt-in). Bei Änderung: `ProviderEnabledChange.notify()` —
/// gleiches Muster wie `ProviderAppAutoEnable`, serialisiert gegen parallele Aufrufe.
public enum ProviderEnablement: Sendable {
    private static let lock = NSLock()

    /// Stellt sicher, dass der Provider für Login/Sync aktiviert ist.
    /// - Returns: `true`, wenn der Enabled-Key neu auf `true` gesetzt und Beobachter benachrichtigt wurden.
    @discardableResult
    public static func ensureEnabled(
        _ providerID: ProviderID,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !AppSettingsKeys.isProviderEnabled(providerID, defaults: defaults) else {
            return false
        }
        defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: providerID))
        ProviderEnabledChange.notify()
        return true
    }
}
