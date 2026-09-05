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

    public static func formattedAbbreviatedRange(
        from bookings: [Booking],
        calendar: Calendar = HotelStayDate.calendar
    ) -> String? {
        guard let bounds = from(bookings: bookings, calendar: calendar) else { return nil }
        let start = bounds.start.formatted(date: .abbreviated, time: .omitted)
        let end = bounds.end.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }
}
