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
            guard bookingStartDay >= startOfToday,
                  bookingStartDay >= tripStartDay,
                  bookingEndDay <= tripEndDay else { return nil }
            return booking.id
        }
    }

    /// Without `restrictingTo`, all bookings in the trip date window. With it, only those IDs that are still open (even outside the window).
    public func bookingIDsToAssign(
        bookings: [Booking],
        trip: Trip,
        restrictingTo seedBookingIDs: Set<UUID>?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UUID] {
        if let seedBookingIDs {
            return bookings.compactMap { booking in
                guard seedBookingIDs.contains(booking.id) else { return nil }
                guard booking.tripID == nil else { return nil }
                guard booking.status != .cancelled else { return nil }
                return booking.id
            }
        }
        return assignableBookingIDs(bookings: bookings, trip: trip, now: now, calendar: calendar)
    }

    public func assignableCount(
        bookings: [Booking],
        startDate: Date,
        endDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard endDate >= startDate else { return 0 }
        let draftTrip = Trip(title: "", startDate: startDate, endDate: endDate)
        return assignableBookingIDs(
            bookings: bookings,
            trip: draftTrip,
            now: now,
            calendar: calendar
        ).count
    }
}
