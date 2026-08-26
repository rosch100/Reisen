import Foundation

/// Cookie-/API-Konstanten für Traveloka-Web (SSOT über Providers + Traveloka-Target).
public enum TravelokaWebConstants {
    public static let origin = "https://www.traveloka.com"
    public static let routePrefix = "en-en"
    public static let clientInterface = "desktop"

    public static let defaultLanguage = "en_EN"
    public static let defaultCountry = "EN"
    public static let defaultCurrency = "EUR"
}

public enum TravelokaLocale {
    /// `en-en` → (`en_EN`, `EN`).
    public static func apiLanguageAndCountry(routePrefix: String) -> (language: String, country: String) {
        let parts = routePrefix.split(separator: "-", omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            return (TravelokaWebConstants.defaultLanguage, TravelokaWebConstants.defaultCountry)
        }
        let lang = String(parts[0])
        let country = String(parts[1]).uppercased()
        return ("\(lang)_\(country)", country)
    }
}
