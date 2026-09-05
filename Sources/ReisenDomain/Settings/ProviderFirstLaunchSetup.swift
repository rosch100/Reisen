import Foundation

/// Gate und Persistenz für die geführte Erststart-Provider-Auswahl.
public enum ProviderFirstLaunchSetup: Sendable {
    /// Settings-Toggle „Erstauswahl der Portale ausblenden“ (Key: `providerSetupDeferred`).
    public static func isInitialSetupHidden(defaults: UserDefaults = AppSettingsDefaults.current) -> Bool {
        defaults.bool(forKey: AppSettingsKeys.providerSetupDeferred)
    }

    public static func setInitialSetupHidden(
        _ hidden: Bool,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) {
        defaults.set(hidden, forKey: AppSettingsKeys.providerSetupDeferred)
    }

    /// `true`, wenn Erstauswahl nicht ausgeblendet ist und kein Sync-Portal aktiv.
    public static func shouldPresent(
        defaults: UserDefaults = AppSettingsDefaults.current,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) -> Bool {
        guard !isInitialSetupHidden(defaults: defaults) else { return false }
        return !syncProviderIDs.contains {
            AppSettingsKeys.isProviderEnabled($0, defaults: defaults)
        }
    }

    public static func markCompleted(defaults: UserDefaults = AppSettingsDefaults.current) {
        defaults.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
    }

    public static func markDeferred(defaults: UserDefaults = AppSettingsDefaults.current) {
        setInitialSetupHidden(true, defaults: defaults)
    }

    /// „Ohne Buchungsportale“: Portale aus, Hide an, Setup completed.
    public static func completeWithoutPortals(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) {
        applySelection(enabledIDs: [], syncProviderIDs: syncProviderIDs, defaults: defaults)
        setInitialSetupHidden(true, defaults: defaults)
        markCompleted(defaults: defaults)
    }
}
