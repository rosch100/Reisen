import Foundation

/// Flug-/Hotel-Drafts für `CalendarTimelineComposer` (SSOT-Fassade).
public enum CalendarTimelineBookingDrafts {
    public static func flightTimeDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String]
    ) -> [CalendarEventDraft] {
        CalendarTimelineFlightDrafts.flightTimeDrafts(
            for: trip,
            bookingsByID: bookingsByID,
            bookingTitles: bookingTitles
        )
    }

    public static func hotelStayDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String]
    ) -> [CalendarEventDraft] {
        CalendarTimelineHotelDrafts.hotelStayDrafts(
            for: trip,
            bookingsByID: bookingsByID,
            bookingTitles: bookingTitles
        )
    }
}
