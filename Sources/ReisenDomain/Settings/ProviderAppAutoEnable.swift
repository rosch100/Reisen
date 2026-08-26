import Foundation

/// Aktiviert Provider einmalig, wenn ihre native iOS-App erkannt wurde.
public enum ProviderAppAutoEnable: Sendable {
    private static let appliedKeyPrefix = "reisen_providerAppAutoEnableApplied_"

    public static func appliedKey(for providerID: ProviderID) -> String {
        "\(appliedKeyPrefix)\(providerID.rawValue)"
    }

    /// Aktiviert erkannte Provider einmalig, wenn der Nutzer sie noch nicht explizit konfiguriert hat.
    /// Gibt `true` zurück, wenn mindestens ein Provider aktiviert wurde.
    @discardableResult
    public static func applyIfNeeded(
        installedProviderIDs: some Collection<ProviderID>,
        defaults: UserDefaults = .standard
    ) -> Bool {
        var didChange = false
        for providerID in installedProviderIDs {
            if applyInstalledProvider(providerID, defaults: defaults) {
                didChange = true
            }
        }
        if didChange {
            ProviderEnabledChange.notify()
        }
        return didChange
    }

    private static func applyInstalledProvider(_ providerID: ProviderID, defaults: UserDefaults) -> Bool {
        let appliedKey = appliedKey(for: providerID)
        guard !defaults.bool(forKey: appliedKey) else { return false }

        let enabledKey = AppSettingsKeys.providerEnabledKey(for: providerID)
        let didEnable = defaults.object(forKey: enabledKey) == nil
        if didEnable {
            defaults.set(true, forKey: enabledKey)
        }
        defaults.set(true, forKey: appliedKey)
        return didEnable
    }
}
