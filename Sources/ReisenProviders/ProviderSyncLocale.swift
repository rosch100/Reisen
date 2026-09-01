import Foundation

import ReisenDomain

/// Kanonische Maschinensprache für unsichtbaren Provider-Sync (nicht Login-UI).
/// Sync-Währung folgt der App-bevorzugten / Locale-Währung (`AppSettingsKeys.preferredCurrency`).
public enum ProviderSyncLocale {
    public static let language = "en"
    /// Identisch zu `CurrencyCode.fallback` (Provider-/Maschinen-Ultima).
    public static let defaultCurrency = CurrencyCode.fallback

    /// Bevorzugte Sync-Abfragewährung; Ultima über Domain-Settings/`CurrencyCode.fallback`.
    public static func currency(
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) -> String {
        AppSettingsKeys.preferredCurrency(defaults: defaults, locale: locale)
    }
}
