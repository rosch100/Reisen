import Foundation

public enum CalendarTimelineFlightDrafts {
    public static func flightTimeDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String]
    ) -> [CalendarEventDraft] {
        var drafts: [CalendarEventDraft] = []
        drafts.reserveCapacity(trip.bookingIDs.count)

        for bookingID in trip.bookingIDs {
            guard let booking = bookingsByID[bookingID], booking.bookingType == .flight else { continue }

            let displayTitle = booking.displayTitle(using: bookingTitles)
            let airline = booking.rateDetails?.airline?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let eventTitle = CalendarTimelineNotes.flightEventTitle(
                displayTitle: displayTitle,
                airline: airline
            )
            let url = booking.externalUrl.flatMap { URL(string: $0) }
            let locationAddress = booking.locationFromAddress
            let locationQuery = booking.locationFromAddress == nil ? booking.locationFrom : nil
            let notes = CalendarTimelineNotes.buildFlightNotes(
                booking: booking,
                displayTitle: displayTitle,
                airline: airline
            )

            drafts.append(
                CalendarEventDraft(
                    role: .flightDeparture,
                    ownerTripID: trip.id,
                    ownerBookingID: booking.id,
                    title: eventTitle,
                    startDate: booking.startAt,
                    endDate: booking.startAt,
                    isAllDay: false,
                    timeZoneOffsetSecondsFromGMT: nil,
                    locationAddress: locationAddress,
                    locationQuery: locationQuery,
                    url: url,
                    notes: notes
                )
            )
        }

        return drafts
    }
}
