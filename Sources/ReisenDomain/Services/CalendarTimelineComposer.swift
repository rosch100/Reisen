import Foundation

public struct CalendarTimelineComposer: Sendable {
    public init() {}

    /// Compose calendar event drafts for a set of trips/bookings based on toggles.
    public func compose(
        trips: [Trip],
        bookings: [Booking],
        bookingTitles: [UUID: String],
        includeTripStartEnd: Bool,
        includeFlightTimes: Bool,
        includeHotelStays: Bool
    ) -> [CalendarEventDraft] {
        if trips.isEmpty { return [] }

        let bookingsByID = Dictionary(uniqueKeysWithValues: bookings.map { ($0.id, $0) })
        var drafts: [CalendarEventDraft] = []
        drafts.reserveCapacity(trips.count * 4)

        for trip in trips {
            CalendarTimelineComposePass.appendDrafts(
                for: trip,
                bookingsByID: bookingsByID,
                bookingTitles: bookingTitles,
                includeTripStartEnd: includeTripStartEnd,
                includeFlightTimes: includeFlightTimes,
                includeHotelStays: includeHotelStays,
                into: &drafts
            )
        }

        return drafts
    }
}
