import Foundation

import ReisenDomain

/// Kanonische Maschinensprache für unsichtbaren Provider-Sync (nicht Login-UI).
/// Sync-Währung ist provider-agnostisch: `ProviderSyncCurrency` (TaskLocal aus SyncStore) bzw. App-/Locale-Preferred.
public enum ProviderSyncLocale {
    public static let language = "en"
    /// Identisch zu `CurrencyCode.fallback` (Provider-/Maschinen-Ultima).
    public static let defaultCurrency = CurrencyCode.fallback

    /// Bevorzugte Sync-Abfragewährung für **jeden** Provider mit Currency-Request.
    /// Ohne Request-Knob: Response-Währung speichern (kein Sync-FX).
    public static func currency(
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) -> String {
        ProviderSyncCurrency.resolve(defaults: defaults, locale: locale)
    }
}
