import Foundation

public enum HotelStayDatePicker {
    public static func dateOnly(fromLocalPickerDate date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("HotelStayDate: DatePicker-Datum ohne Y/M/D")
        }
        return HotelStayDate.dateOnly(year: year, month: month, day: day)
    }
}
