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
}
