import Foundation

/// Plattformeinheitliche Formatierungs-Helfer für iOS/macOS UI.
public enum Formatting {
    public static func formatCurrencyAmount(_ amount: Double, currencyCode: String?) -> String {
        let currency = currencyCode ?? "EUR"
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
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

