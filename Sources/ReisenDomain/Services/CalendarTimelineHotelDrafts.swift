import Foundation

public enum CalendarTimelineHotelDrafts {
    public static func hotelStayDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String]
    ) -> [CalendarEventDraft] {
        var drafts: [CalendarEventDraft] = []
        drafts.reserveCapacity(trip.bookingIDs.count)

        for bookingID in trip.bookingIDs {
            guard let booking = bookingsByID[bookingID], booking.bookingType == .hotel else { continue }
            let title = booking.displayTitle(using: bookingTitles)
            drafts.append(
                CalendarTimelineHotelDraftBuilder.draft(trip: trip, booking: booking, title: title)
            )
        }

        return drafts
    }
}
