import Foundation
import ReisenDomain

/// Plattformeinheitliche Formatierungs-Helfer für iOS/macOS UI.
public enum Formatting {
    /// Währungsbetrag für die UI. Locale folgt `L10n.locale` (Gerät/App-Sprache), kein festes `de_DE`.
    public static func formatCurrencyAmount(
        _ amount: Decimal,
        currencyCode: String?,
        locale: Locale = L10n.locale
    ) -> String {
        let currency = currencyCode ?? "EUR"
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        let number = amount as NSDecimalNumber
        return formatter.string(from: number) ?? "\(number) \(currency)"
    }

    public static func formatCurrencyAmount(
        _ amount: Double,
        currencyCode: String?,
        locale: Locale = L10n.locale
    ) -> String {
        let decimal = DecimalJSON.parse(amount) ?? Decimal(amount)
        return formatCurrencyAmount(decimal, currencyCode: currencyCode, locale: locale)
    }

    public static func minutesToHHmm(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    public static func formatOrtszeit(
        _ date: Date,
        dateFormat: String,
        timeZone: TimeZone
    ) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE_POSIX")
        df.timeZone = timeZone
        df.dateFormat = dateFormat
        return df.string(from: date)
    }
}
