import Foundation

/// SSOT-Zugriff auf lokalisierte UI-Texte (String Catalog in `Resources/Localizable.xcstrings`).
public enum L10n {
    public static let bundle: Bundle = .module

    /// Test-Override; Produktivcode nutzt `.current`.
    private nonisolated(unsafe) static var _locale: Locale = .current
    private static let localeLock = NSRecursiveLock()
    public static var locale: Locale {
        get {
            localeLock.lock()
            defer { localeLock.unlock() }
            return _locale
        }
        set {
            localeLock.lock()
            _locale = newValue
            localeLock.unlock()
        }
    }

    /// Hält die Locale für den gesamten Block (Tests: erwarteter und tatsächlicher String).
    public static func withLocale<T>(_ locale: Locale, _ operation: () throws -> T) rethrows -> T {
        localeLock.lock()
        let previous = _locale
        _locale = locale
        defer {
            _locale = previous
            localeLock.unlock()
        }
        return try operation()
    }

    public static func string(_ key: L10nKey) -> String {
        localeLock.lock()
        defer { localeLock.unlock() }
        if let language = _locale.language.languageCode?.identifier,
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
        return String(localized: String.LocalizationValue(key.rawValue), bundle: bundle, locale: _locale)
    }

    public static func format(_ key: L10nKey, _ arguments: any CVarArg...) -> String {
        localeLock.lock()
        defer { localeLock.unlock() }
        return String(format: string(key), locale: _locale, arguments: arguments)
    }

    public static func yesNo(_ value: Bool) -> String {
        string(value ? .commonYes : .commonNo)
    }
}
