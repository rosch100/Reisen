import Foundation

/// Gate und Persistenz für die geführte Erststart-Provider-Auswahl.
public enum ProviderFirstLaunchSetup: Sendable {
    /// `true`, wenn weder completed noch deferred gesetzt ist.
    public static func shouldPresent(defaults: UserDefaults = AppSettingsDefaults.current) -> Bool {
        !defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted)
            && !defaults.bool(forKey: AppSettingsKeys.providerSetupDeferred)
    }

    public static func markCompleted(defaults: UserDefaults = AppSettingsDefaults.current) {
        defaults.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
    }

    public static func markDeferred(defaults: UserDefaults = AppSettingsDefaults.current) {
        defaults.set(true, forKey: AppSettingsKeys.providerSetupDeferred)
    }

    /// Setzt `providerEnabled` explizit true für `enabledIDs`, false für übrige `syncProviderIDs`.
    public static func applySelection(
        enabledIDs: Set<ProviderID>,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) {
        for providerID in syncProviderIDs {
            let key = AppSettingsKeys.providerEnabledKey(for: providerID)
            defaults.set(enabledIDs.contains(providerID), forKey: key)
        }
    }

    /// Bestandskunden: vorhandener `providerEnabled_*`-Key → `setupCompleted` (kein Sheet).
    /// - Returns: `true`, wenn completed in diesem Aufruf gesetzt wurde.
    @discardableResult
    public static func bootstrapCompletedIfExistingProviders(
        defaults: UserDefaults = AppSettingsDefaults.current,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) -> Bool {
        guard !defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted) else { return false }

        let hasExistingProviderKey = syncProviderIDs.contains { providerID in
            defaults.object(forKey: AppSettingsKeys.providerEnabledKey(for: providerID)) != nil
        }
        guard hasExistingProviderKey else { return false }

        markCompleted(defaults: defaults)
        return true
    }
}
