import Foundation
import ReisenDomain

/// Ticket-typische Datumsangaben → `Date`. Mehrdeutige Slash-Daten bleiben `nil`.
enum PasteImportTicketDate {
    static func parse(_ raw: String?) -> Date? {
        guard let text = NonEmpty.string(raw) else { return nil }
        if let date = iso8601(text) { return date }
        if looksAmbiguousSlash(text) { return nil }
        return local(text)
    }

    /// `withInternetDateTime` braucht eine Zeitzone; ohne `Z`/Offset bleibt der Wert lokal.
    private static func iso8601(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }

    private static func looksAmbiguousSlash(_ text: String) -> Bool {
        text.contains("/") && text.contains(where: \.isNumber)
    }

    private static func local(_ text: String) -> Date? {
        let calendar = Calendar.current
        for formatter in formatters {
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static let formatters: [DateFormatter] = {
        let english: [(String, Locale)] = [
            ("yyyy-MM-dd'T'HH:mm:ss", Locale(identifier: "en_US_POSIX")),
            ("yyyy-MM-dd'T'HH:mm", Locale(identifier: "en_US_POSIX")),
            ("yyyy-MM-dd HH:mm:ss", Locale(identifier: "en_US_POSIX")),
            ("yyyy-MM-dd HH:mm", Locale(identifier: "en_US_POSIX")),
            ("yyyy-MM-dd", Locale(identifier: "en_US_POSIX")),
            ("EEE, d MMM yyyy HH:mm", Locale(identifier: "en_US_POSIX")),
            ("EEE, d MMM yyyy", Locale(identifier: "en_US_POSIX")),
            ("EEEE, d MMMM yyyy HH:mm", Locale(identifier: "en_US_POSIX")),
            ("EEEE, d MMMM yyyy", Locale(identifier: "en_US_POSIX")),
            ("EEE, d MMMM yyyy", Locale(identifier: "en_US_POSIX")),
            ("d MMM yyyy HH:mm", Locale(identifier: "en_US_POSIX")),
            ("d MMMM yyyy HH:mm", Locale(identifier: "en_US_POSIX")),
            ("d MMM yyyy", Locale(identifier: "en_US_POSIX")),
        ]
        let german: [(String, Locale)] = [
            ("dd.MM.yyyy HH:mm:ss", Locale(identifier: "de_DE")),
            ("dd.MM.yyyy HH:mm", Locale(identifier: "de_DE")),
            ("d.MM.yyyy HH:mm", Locale(identifier: "de_DE")),
            ("dd.MM.yyyy", Locale(identifier: "de_DE")),
            ("d. MMMM yyyy HH:mm", Locale(identifier: "de_DE")),
            ("d. MMMM yyyy", Locale(identifier: "de_DE")),
        ]
        return (english + german).map { format, locale in
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = format
            formatter.formatterBehavior = .behavior10_4
            return formatter
        }
    }()
}
