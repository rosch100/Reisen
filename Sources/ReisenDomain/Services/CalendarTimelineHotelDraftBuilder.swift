import Foundation

public enum CalendarTimelineHotelDraftBuilder {
    public static func draft(
        trip: Trip,
        booking: Booking,
        title: String
    ) -> CalendarEventDraft {
        let url = booking.externalUrl.flatMap { URL(string: $0) }
        let locationAddress = booking.locationToAddress ?? booking.locationFromAddress
        let locationQuery: String? = (locationAddress == nil)
            ? (booking.locationTo ?? booking.locationFrom)
            : nil

        return CalendarEventDraft(
            role: .hotelStay,
            ownerTripID: trip.id,
            ownerBookingID: booking.id,
            title: "Hotel: \(title)",
            startDate: HotelStayDate.dateOnly(
                fromStoredOrParsed: booking.startAt,
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            ),
            endDate: HotelStayDate.dateOnly(
                fromStoredOrParsed: booking.endAt,
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            ),
            isAllDay: true,
            timeZoneOffsetSecondsFromGMT: nil,
            locationAddress: locationAddress,
            locationQuery: locationQuery,
            url: url,
            notes: CalendarTimelineNotes.buildHotelNotes(
                booking: booking,
                displayTitle: title
            )
        )
    }
}
