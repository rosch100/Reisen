import Foundation

public enum CalendarTimelineTripBoundaryDrafts {
    public static func drafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking]
    ) -> [CalendarEventDraft] {
        let tzOffset = trip.bookingIDs.compactMap { bookingsByID[$0]?.hotelOffsetSeconds }.first
        let tripLocationAddress = trip.bookingIDs
            .compactMap { bookingsByID[$0] }
            .compactMap { $0.locationToAddress ?? $0.locationFromAddress }
            .first
        let tripLocationQuery = tripLocationAddress == nil ? trip.destination : nil

        return [
            boundaryDraft(
                role: .tripStart,
                trip: trip,
                date: trip.startDate,
                titlePrefix: "Reisebeginn",
                tzOffset: tzOffset,
                locationAddress: tripLocationAddress,
                locationQuery: tripLocationQuery,
                isStart: true,
                bookingsByID: bookingsByID
            ),
            boundaryDraft(
                role: .tripEnd,
                trip: trip,
                date: trip.endDate,
                titlePrefix: "Reiseende",
                tzOffset: tzOffset,
                locationAddress: tripLocationAddress,
                locationQuery: tripLocationQuery,
                isStart: false,
                bookingsByID: bookingsByID
            ),
        ]
    }

    private static func boundaryDraft(
        role: CalendarEventRole,
        trip: Trip,
        date: Date,
        titlePrefix: String,
        tzOffset: Int?,
        locationAddress: String?,
        locationQuery: String?,
        isStart: Bool,
        bookingsByID: [UUID: Booking]
    ) -> CalendarEventDraft {
        CalendarEventDraft(
            role: role,
            ownerTripID: trip.id,
            ownerBookingID: nil,
            title: "\(titlePrefix): \(trip.title)",
            startDate: date,
            endDate: date,
            isAllDay: true,
            timeZoneOffsetSecondsFromGMT: tzOffset,
            locationAddress: locationAddress,
            locationQuery: locationQuery,
            url: nil,
            notes: CalendarTimelineNotes.tripStartEndNotes(
                for: trip,
                bookingsByID: bookingsByID,
                isStart: isStart
            )
        )
    }
}
