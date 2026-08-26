import Foundation

public enum CalendarTimelineHotelNotes {
    public static func build(booking: Booking, displayTitle: String) -> String {
        var lines: [String] = ["Hotel: \(displayTitle)"]

        if let confirmation = booking.confirmationCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !confirmation.isEmpty {
            lines.append("Bestätigung: \(confirmation)")
        }
        if let checkInMinutes = booking.hotelCheckInMinutes {
            lines.append("Check-in: \(CalendarTimelineNotes.formatMinutes(checkInMinutes))")
        }
        if let checkOutMinutes = booking.hotelCheckOutMinutes {
            lines.append("Check-out: \(CalendarTimelineNotes.formatMinutes(checkOutMinutes))")
        }
        return lines.joined(separator: "\n")
    }

    public static func tripStartEndNotes(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        isStart: Bool
    ) -> String? {
        CalendarTimelineTripHotelNotes.tripStartEndNotes(
            for: trip,
            bookingsByID: bookingsByID,
            isStart: isStart
        )
    }
}
