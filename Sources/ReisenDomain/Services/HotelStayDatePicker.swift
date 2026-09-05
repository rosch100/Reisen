import Foundation

public enum HotelStayDatePicker {
    public static func dateOnly(fromLocalPickerDate date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("HotelStayDate: DatePicker-Datum ohne Y/M/D")
        }
        return HotelStayDate.dateOnly(year: year, month: month, day: day)
    }

    /// Maps a stored GMT date-only anchor to a DatePicker value that shows the same Y/M/D in `calendar` (default `.current`).
    public static func localPickerDate(fromStored date: Date, calendar: Calendar = .current) -> Date {
        let parts = HotelStayDate.calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("HotelStayDate: gespeicherter Anker ohne Y/M/D")
        }
        guard let pickerDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            preconditionFailure("HotelStayDate: ungültiges Picker-Datum \(year)-\(month)-\(day)")
        }
        return pickerDate
    }
}
