import Foundation

/// SSOT-Zugriff auf lokalisierte UI-Texte (String Catalog in `Resources/Localizable.xcstrings`).
public enum L10n {
    public static let bundle: Bundle = .module

    /// Test-Override; Produktivcode nutzt `.current`.
    private nonisolated(unsafe) static var _locale: Locale = .current
    public static var locale: Locale {
        get { _locale }
        set { _locale = newValue }
    }

    public static func string(_ key: L10nKey) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: bundle, locale: locale)
    }

    public static func format(_ key: L10nKey, _ arguments: any CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    public static func yesNo(_ value: Bool) -> String {
        string(value ? .commonYes : .commonNo)
    }
}
