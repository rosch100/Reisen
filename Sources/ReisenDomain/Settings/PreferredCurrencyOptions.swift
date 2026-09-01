import Foundation

/// ISO-4217-Auswahl für Settings (HIG: Picker, kein Freitext).
public enum PreferredCurrencyOptions {
    /// Häufige Reisewährungen; Locale- und gespeicherte Währung immer enthalten.
    public static func codes(locale: Locale = .current, including stored: String? = nil) -> [String] {
        var ordered = [
            "EUR", "USD", "GBP", "CHF", "JPY", "CAD", "AUD", "NZD",
            "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "THB",
            "SGD", "HKD", "CNY", "INR", "IDR", "MYR", "PHP", "VND",
            "KRW", "MXN", "BRL", "ZAR", "AED", "ILS",
        ]
        func prepend(_ raw: String?) {
            guard let code = raw.map(CurrencyCode.normalize),
                  !code.isEmpty,
                  !ordered.contains(code) else { return }
            ordered.insert(code, at: 0)
        }
        prepend(locale.currency?.identifier)
        prepend(stored)
        return ordered
    }

    public static func displayName(for code: String, locale: Locale = .current) -> String {
        let normalized = CurrencyCode.normalize(code)
        if let name = locale.localizedString(forCurrencyCode: normalized) {
            return "\(normalized) – \(name)"
        }
        return normalized
    }
}
