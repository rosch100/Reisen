import Foundation
import ReisenDomain

/// Provider-agnostische Sync-Währung: Orchestrierung setzt einmal pro Sync; alle Provider lesen über `ProviderSyncLocale.currency()`.
/// Request-fähige Provider (derzeit Airbnb/Traveloka) nutzen den Wert in Query/Header.
/// Ohne API-Knob speichern Provider die gelieferte Antwortwährung — kein Sync-FX.
public enum ProviderSyncCurrency {
    /// Explizit von SyncStore gesetzt; sonst Fallback auf App-/Locale-Preferred.
    @TaskLocal public static var requested: String?

    public static func resolve(
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) -> String {
        if let requested {
            let normalized = CurrencyCode.normalize(requested)
            if !normalized.isEmpty {
                return normalized
            }
        }
        return AppSettingsKeys.preferredCurrency(defaults: defaults, locale: locale)
    }
}
