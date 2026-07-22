import Foundation

/// Hotel-Aufenthaltsdaten sind **reine Kalenderdaten** (Y/M/D).
/// Keine Uhrzeit, keine Hotel-/User-Zeitzone in der Semantik.
///
/// Speicherformat: Mitternacht **GMT** des Aufenthaltstags (Datumsanker).
/// Check-in-/Check-out-**Uhrzeiten** liegen ausschließlich in
/// `hotelCheckInMinutes` / `hotelCheckOutMinutes`.
public enum HotelStayDate: Sendable {
    public static let timeZone = TimeZone(secondsFromGMT: 0)!

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Baut den kanonischen Datumsanker (GMT-Mitternacht) aus Y/M/D.
    public static func dateOnly(year: Int, month: Int, day: Int) -> Date {
        let calendar = Self.calendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            preconditionFailure("HotelStayDate: ungültiges Kalenderdatum \(year)-\(month)-\(day)")
        }
        return date
    }

    /// Parst `yyyy-MM-dd` (optional mit Trailing-Zeit) → Datumsanker.
    public static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        let prefix = String(trimmed.prefix(10))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: prefix)
    }

    /// Kanonisiert gespeicherte/API-Instants zu Datumsankern.
    /// Verwirft die Uhrzeit. Stellt Legacy-„Hotel-Mitternacht“-Speicherung
    /// wieder her, wenn der Instant in der früheren Hotel-TZ genau Mitternacht war.
    public static func dateOnly(
        fromStoredOrParsed date: Date,
        legacyHotelOffsetSeconds: Int? = nil
    ) -> Date {
        if let offset = legacyHotelOffsetSeconds,
           let hotelTZ = TimeZone(secondsFromGMT: offset) {
            var hotelCalendar = Calendar(identifier: .gregorian)
            hotelCalendar.timeZone = hotelTZ
            let hotelParts = hotelCalendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            if hotelParts.hour == 0,
               hotelParts.minute == 0,
               (hotelParts.second ?? 0) == 0,
               let year = hotelParts.year,
               let month = hotelParts.month,
               let day = hotelParts.day {
                return dateOnly(year: year, month: month, day: day)
            }
        }

        let calendar = Self.calendar
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("HotelStayDate: Datum ohne Y/M/D")
        }
        return dateOnly(year: year, month: month, day: day)
    }

    /// DatePicker (`.date`) liefert Mitternacht in der **lokalen** Kalender-TZ.
    /// Daraus Y/M/D lesen und als GMT-Datumsanker speichern.
    public static func dateOnly(fromLocalPickerDate date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("HotelStayDate: DatePicker-Datum ohne Y/M/D")
        }
        return dateOnly(year: year, month: month, day: day)
    }

    /// Anzeige eines Datumsankers (immer GMT-Y/M/D, nie Hotel-TZ).
    /// `legacyHotelOffsetSeconds` nur zur Wiederherstellung alter Hotel-Mitternacht-Speicherung.
    public static func format(
        _ date: Date,
        dateFormat: String,
        legacyHotelOffsetSeconds: Int? = nil,
        locale: Locale = Locale(identifier: "de_DE_POSIX")
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = dateFormat
        let anchor = dateOnly(fromStoredOrParsed: date, legacyHotelOffsetSeconds: legacyHotelOffsetSeconds)
        return formatter.string(from: anchor)
    }
}
