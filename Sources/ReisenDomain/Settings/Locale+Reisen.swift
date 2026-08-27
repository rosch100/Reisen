import Foundation

extension Locale {
    /// `true` wenn die bevorzugte Sprache Deutsch ist (App-Standard: `de`).
    public var reisenPrefersGerman: Bool {
        if language.languageCode?.identifier == "de" { return true }
        return identifier.hasPrefix("de")
    }
}
