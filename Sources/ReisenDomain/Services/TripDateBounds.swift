import Foundation

/// Inclusive calendar-day bounds for a trip derived from bookings.
/// Default calendar is `HotelStayDate.calendar` (GMT date anchors), not device TZ.
public enum TripDateBounds {
    public static func from(
        bookings: [Booking],
        calendar: Calendar = HotelStayDate.calendar
    ) -> (start: Date, end: Date)? {
        guard !bookings.isEmpty else { return nil }
        guard let minStart = bookings.min(by: { $0.startAt < $1.startAt }),
              let maxEnd = bookings.max(by: { $0.endAt < $1.endAt }) else {
            return nil
        }
        let start = calendar.startOfDay(for: minStart.startAt)
        let end = calendar.startOfDay(for: maxEnd.endAt)
        return (start, end)
    }

    /// Inclusive trip period display from stored HotelStayDate GMT anchors.
    /// Uses `HotelStayDate.format` — never device `Date.formatted` (TZ day shift).
    public static func formattedAbbreviatedRange(start: Date, end: Date) -> String {
        let startText = HotelStayDate.format(start, dateFormat: "d.M.yyyy")
        let endText = HotelStayDate.format(end, dateFormat: "d.M.yyyy")
        return "\(startText) – \(endText)"
    }

    public static func formattedAbbreviatedRange(
        from bookings: [Booking],
        calendar: Calendar = HotelStayDate.calendar
    ) -> String? {
        guard let bounds = from(bookings: bookings, calendar: calendar) else { return nil }
        return formattedAbbreviatedRange(start: bounds.start, end: bounds.end)
    }
}
