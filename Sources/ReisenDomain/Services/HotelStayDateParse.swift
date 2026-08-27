import Foundation

public enum HotelStayDateParse {
    /// Parst `yyyy-MM-dd` (optional mit Trailing-Zeit) → Datumsanker.
    public static func parse(_ raw: String) -> Date? {
        guard let trimmed = NonEmpty.string(raw), trimmed.count >= 10 else { return nil }
        return day(from: String(trimmed.prefix(10)), format: "yyyy-MM-dd", locale: "en_US_POSIX")
    }

    /// Parst `dd.MM.yyyy` → denselben GMT-Datumsanker.
    public static func parseGerman(_ raw: String) -> Date? {
        guard let trimmed = NonEmpty.string(raw) else { return nil }
        return day(from: trimmed, format: "dd.MM.yyyy", locale: "de_DE_POSIX")
    }

    private static func day(from raw: String, format: String, locale: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.timeZone = HotelStayDate.timeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter.date(from: raw)
    }
}
