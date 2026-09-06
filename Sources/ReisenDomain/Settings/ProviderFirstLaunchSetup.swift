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

    /// `true`, wenn kein Sync-Portal aktiv ist und Hide das Sheet nicht unterdrücken darf.
    /// Hide gilt nur nach `setupCompleted` (Ohne Buchungsportale / Settings nach Abschluss).
    public static func shouldPresent(
        defaults: UserDefaults = AppSettingsDefaults.current,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) -> Bool {
        let hasEnabledPortal = syncProviderIDs.contains {
            AppSettingsKeys.isProviderEnabled($0, defaults: defaults)
        }
        guard !hasEnabledPortal else { return false }
        guard isInitialSetupHidden(defaults: defaults) else { return true }
        return !defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted)
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
