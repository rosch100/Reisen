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

    /// Bestandskunden: mindestens ein Portal explizit aktiv → `setupCompleted` (kein Sheet).
    /// - Returns: `true`, wenn completed in diesem Aufruf gesetzt wurde.
    @discardableResult
    public static func bootstrapCompletedIfExistingProviders(
        defaults: UserDefaults = AppSettingsDefaults.current,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) -> Bool {
        guard !defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted) else { return false }

        let hasEnabledProvider = syncProviderIDs.contains { providerID in
            AppSettingsKeys.isProviderEnabled(providerID, defaults: defaults)
        }
        guard hasEnabledProvider else { return false }

        markCompleted(defaults: defaults)
        return true
    }
}
