import Foundation

extension ProviderFirstLaunchSetup {
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
