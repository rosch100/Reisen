import Foundation

/// Inclusive calendar-day containment of a booking in a trip window (SSOT).
/// Default calendar is `HotelStayDate.calendar` (GMT date anchors), not device TZ.
public enum TripBookingDateWindow {
    public static func contains(
        bookingStart: Date,
        bookingEnd: Date,
        tripStart: Date,
        tripEnd: Date,
        calendar: Calendar = HotelStayDate.calendar
    ) -> Bool {
        let tripStartDay = calendar.startOfDay(for: tripStart)
        let tripEndDay = calendar.startOfDay(for: tripEnd)
        let bookingStartDay = calendar.startOfDay(for: bookingStart)
        let bookingEndDay = calendar.startOfDay(for: bookingEnd)
        return bookingStartDay >= tripStartDay && bookingEndDay <= tripEndDay
    }

    /// Einstiegs-Reise nur wenn das Buchungsdatum im Fenster liegt; sonst `nil` (Offene Buchungen).
    public static func assignedTripID(
        entryTripID: UUID?,
        bookingStart: Date,
        bookingEnd: Date,
        tripStart: Date?,
        tripEnd: Date?,
        calendar: Calendar = HotelStayDate.calendar
    ) -> UUID? {
        guard let entryTripID, let tripStart, let tripEnd else { return nil }
        guard contains(
            bookingStart: bookingStart,
            bookingEnd: bookingEnd,
            tripStart: tripStart,
            tripEnd: tripEnd,
            calendar: calendar
        ) else { return nil }
        return entryTripID
    }
}
