import Foundation

public enum HotelStayDateStored {
    /// Kanonisiert gespeicherte/API-Instants zu Datumsankern.
    public static func dateOnly(
        fromStoredOrParsed date: Date,
        legacyHotelOffsetSeconds: Int? = nil
    ) -> Date {
        if let legacy = HotelStayDateLegacy.dateOnlyIfLegacyMidnight(
            date,
            legacyHotelOffsetSeconds: legacyHotelOffsetSeconds
        ) {
            return legacy
        }

        let parts = HotelStayDate.calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("HotelStayDate: Datum ohne Y/M/D")
        }
        return HotelStayDate.dateOnly(year: year, month: month, day: day)
    }

    public static func dateOnly(fromLocalPickerDate date: Date, calendar: Calendar = .current) -> Date {
        HotelStayDatePicker.dateOnly(fromLocalPickerDate: date, calendar: calendar)
    }
}
