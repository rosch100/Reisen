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

    public static func parse(_ raw: String) -> Date? {
        HotelStayDateParse.parse(raw)
    }

    public static func dateOnly(
        fromStoredOrParsed date: Date,
        legacyHotelOffsetSeconds: Int? = nil
    ) -> Date {
        HotelStayDateStored.dateOnly(
            fromStoredOrParsed: date,
            legacyHotelOffsetSeconds: legacyHotelOffsetSeconds
        )
    }

    public static func dateOnly(fromLocalPickerDate date: Date, calendar: Calendar = .current) -> Date {
        HotelStayDateStored.dateOnly(fromLocalPickerDate: date, calendar: calendar)
    }

    public static func format(
        _ date: Date,
        dateFormat: String,
        legacyHotelOffsetSeconds: Int? = nil,
        locale: Locale = Locale(identifier: "de_DE_POSIX")
    ) -> String {
        HotelStayDateFormat.format(
            date,
            dateFormat: dateFormat,
            legacyHotelOffsetSeconds: legacyHotelOffsetSeconds,
            locale: locale
        )
    }
}
