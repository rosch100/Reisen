import Foundation

/// Assigns open bookings to a trip by inclusive calendar-day containment.
public struct TripBookingAssignment: Sendable {
    public init() {}

    public func assignableBookingIDs(
        bookings: [Booking],
        trip: Trip,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UUID] {
        let startOfToday = calendar.startOfDay(for: now)
        let tripStartDay = calendar.startOfDay(for: trip.startDate)
        let tripEndDay = calendar.startOfDay(for: trip.endDate)

        return bookings.compactMap { booking in
            guard booking.tripID == nil else { return nil }
            guard booking.status != .cancelled else { return nil }
            let bookingStartDay = calendar.startOfDay(for: booking.startAt)
            let bookingEndDay = calendar.startOfDay(for: booking.endAt)
            guard bookingStartDay >= startOfToday else { return nil }
            guard bookingStartDay >= tripStartDay, bookingEndDay <= tripEndDay else { return nil }
            return booking.id
        }
    }
}
