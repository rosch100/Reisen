import Foundation

public enum CalendarTimelineTripHotelNotes {
    public static func tripStartEndNotes(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        isStart: Bool
    ) -> String? {
        let hotels = trip.bookingIDs.compactMap { bookingsByID[$0] }.filter { $0.bookingType == .hotel }
        guard !hotels.isEmpty else { return nil }
        return isStart
            ? CalendarTimelineTripCheckNotes.checkInNote(hotels: hotels)
            : CalendarTimelineTripCheckNotes.checkOutNote(hotels: hotels)
    }
}
