import Foundation

public enum CalendarTimelineTripCheckNotes {
    public static func checkInNote(hotels: [Booking]) -> String? {
        guard let checkInMinutes = hotels.compactMap(\.hotelCheckInMinutes).first else { return nil }
        return "Check-in: \(CalendarTimelineNotes.formatMinutes(checkInMinutes))"
    }

    public static func checkOutNote(hotels: [Booking]) -> String? {
        guard let checkOutMinutes = hotels.compactMap(\.hotelCheckOutMinutes).first else { return nil }
        return "Check-out: \(CalendarTimelineNotes.formatMinutes(checkOutMinutes))"
    }
}
