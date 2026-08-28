import Foundation

/// Inclusive calendar-day containment of a booking in a trip window (SSOT).
public enum TripBookingDateWindow {
    public static func contains(
        bookingStart: Date,
        bookingEnd: Date,
        tripStart: Date,
        tripEnd: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let tripStartDay = calendar.startOfDay(for: tripStart)
        let tripEndDay = calendar.startOfDay(for: tripEnd)
        let bookingStartDay = calendar.startOfDay(for: bookingStart)
        let bookingEndDay = calendar.startOfDay(for: bookingEnd)
        return bookingStartDay >= tripStartDay && bookingEndDay <= tripEndDay
    }
}
