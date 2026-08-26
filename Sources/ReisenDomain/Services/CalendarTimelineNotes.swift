import Foundation

/// Notiz-/Titel-Hilfen für Kalender-Timeline-Drafts (SSOT-Fassade).
public enum CalendarTimelineNotes {
    public static func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    public static func flightEventTitle(displayTitle: String, airline: String?) -> String {
        CalendarTimelineFlightNotes.eventTitle(displayTitle: displayTitle, airline: airline)
    }

    public static func buildFlightNotes(
        booking: Booking,
        displayTitle: String,
        airline: String?
    ) -> String {
        CalendarTimelineFlightNotes.build(
            booking: booking,
            displayTitle: displayTitle,
            airline: airline
        )
    }

    public static func buildHotelNotes(booking: Booking, displayTitle: String) -> String {
        CalendarTimelineHotelNotes.build(booking: booking, displayTitle: displayTitle)
    }

    public static func tripStartEndNotes(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        isStart: Bool
    ) -> String? {
        CalendarTimelineHotelNotes.tripStartEndNotes(
            for: trip,
            bookingsByID: bookingsByID,
            isStart: isStart
        )
    }
}
