import Foundation

/// SSOT-Zugriff auf lokalisierte UI-Texte (String Catalog in `Resources/Localizable.xcstrings`).
public enum L10n {
    public static let bundle: Bundle = .module

    /// Test-Override pro Task; Produktivcode sieht `nil` und nutzt `.current`.
    @TaskLocal static var taskLocale: Locale?

    public static var locale: Locale { taskLocale ?? .current }

    /// Hält die Locale für den gesamten Block (parallel-sicher, kein Prozess-Global).
    public static func withLocale<T>(_ locale: Locale, _ operation: () throws -> T) rethrows -> T {
        try $taskLocale.withValue(locale, operation: operation)
    }

    public static func string(_ key: L10nKey) -> String {
        if let language = locale.language.languageCode?.identifier,
           let path = bundle.path(forResource: language, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            let value = localizedBundle.localizedString(
                forKey: key.rawValue,
                value: key.rawValue,
                table: "Localizable"
            )
            if value != key.rawValue {
                return value
            }
        }
        return String(localized: String.LocalizationValue(key.rawValue), bundle: bundle, locale: locale)
    }

    public static func format(_ key: L10nKey, _ arguments: any CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    public static func yesNo(_ value: Bool) -> String {
        string(value ? .commonYes : .commonNo)
    }
}
