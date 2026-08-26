import Foundation

public enum HotelStayDateParse {
    /// Parst `yyyy-MM-dd` (optional mit Trailing-Zeit) → Datumsanker.
    public static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        let prefix = String(trimmed.prefix(10))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = HotelStayDate.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: prefix)
    }
}
