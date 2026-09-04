import Foundation

/// Gate und Persistenz für die geführte Erststart-Provider-Auswahl.
public enum ProviderFirstLaunchSetup: Sendable {
    /// `true`, wenn weder completed noch deferred gesetzt ist.
    public static func shouldPresent(defaults: UserDefaults = AppSettingsDefaults.current) -> Bool {
        !defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted)
            && !defaults.bool(forKey: AppSettingsKeys.providerSetupDeferred)
    }

    /// Continue nur mit mindestens einem Provider; leere Auswahl darf Host nicht abschließen.
    public static func acceptsContinue(enabledIDs: Set<ProviderID>) -> Bool {
        !enabledIDs.isEmpty
    }

    public static func markCompleted(defaults: UserDefaults = AppSettingsDefaults.current) {
        defaults.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
    }

    public static func markDeferred(defaults: UserDefaults = AppSettingsDefaults.current) {
        defaults.set(true, forKey: AppSettingsKeys.providerSetupDeferred)
    }
}
