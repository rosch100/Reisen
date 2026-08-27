import Foundation

public enum CalendarTimelineTripCheckNotes {
    public static func checkInNote(hotels: [Booking]) -> String? {
        guard let checkInMinutes = hotels.compactMap(\.hotelCheckInMinutes).first else { return nil }
        return L10n.format(.calendarCheckIn, CalendarTimelineNotes.formatMinutes(checkInMinutes))
    }

    public static func checkOutNote(hotels: [Booking]) -> String? {
        guard let checkOutMinutes = hotels.compactMap(\.hotelCheckOutMinutes).first else { return nil }
        return L10n.format(.calendarCheckOut, CalendarTimelineNotes.formatMinutes(checkOutMinutes))
    }
}
