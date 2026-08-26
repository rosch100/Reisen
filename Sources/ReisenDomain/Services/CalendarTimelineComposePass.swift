import Foundation

public enum CalendarTimelineComposePass {
    public static func appendDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String],
        includeTripStartEnd: Bool,
        includeFlightTimes: Bool,
        includeHotelStays: Bool,
        into drafts: inout [CalendarEventDraft]
    ) {
        if includeTripStartEnd {
            drafts.append(contentsOf: CalendarTimelineTripBoundaryDrafts.drafts(
                for: trip,
                bookingsByID: bookingsByID
            ))
        }
        if includeFlightTimes {
            drafts.append(contentsOf: CalendarTimelineBookingDrafts.flightTimeDrafts(
                for: trip,
                bookingsByID: bookingsByID,
                bookingTitles: bookingTitles
            ))
        }
        if includeHotelStays {
            drafts.append(contentsOf: CalendarTimelineBookingDrafts.hotelStayDrafts(
                for: trip,
                bookingsByID: bookingsByID,
                bookingTitles: bookingTitles
            ))
        }
    }
}
