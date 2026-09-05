import Foundation

/// Assigns open bookings to a trip by inclusive calendar-day containment.
public struct TripBookingAssignment: Sendable {
    public init() {}

    /// - Parameters:
    ///   - upcomingCalendar: Override for the „ab heute“ gate only.
    ///     `nil` → `booking.bookingType.listInclusionCalendar` (Hotel GMT, sonst Gerätekalender).
    ///   - windowCalendar: Trip date-window SSOT; default `HotelStayDate.calendar` (R18).
    public func assignableBookingIDs(
        bookings: [Booking],
        trip: Trip,
        now: Date = Date(),
        upcomingCalendar: Calendar? = nil,
        windowCalendar: Calendar = HotelStayDate.calendar
    ) -> [UUID] {
        bookings.compactMap { booking in
            guard booking.tripID == nil else { return nil }
            guard booking.status != .cancelled else { return nil }
            let listCal = upcomingCalendar ?? booking.bookingType.listInclusionCalendar
            let startOfToday = listCal.startOfDay(for: now)
            let bookingStartDay = listCal.startOfDay(for: booking.startAt)
            guard bookingStartDay >= startOfToday else { return nil }
            guard TripBookingDateWindow.contains(
                bookingStart: booking.startAt,
                bookingEnd: booking.endAt,
                tripStart: trip.startDate,
                tripEnd: trip.endDate,
                calendar: windowCalendar
            ) else { return nil }
            return booking.id
        }
    }

    /// Without `restrictingTo`, all bookings in the trip date window. With it, only those IDs that are still open (even outside the window).
    public func bookingIDsToAssign(
        bookings: [Booking],
        trip: Trip,
        restrictingTo seedBookingIDs: Set<UUID>?,
        now: Date = Date(),
        upcomingCalendar: Calendar? = nil,
        windowCalendar: Calendar = HotelStayDate.calendar
    ) -> [UUID] {
        if let seedBookingIDs {
            return bookings.compactMap { booking in
                guard seedBookingIDs.contains(booking.id) else { return nil }
                guard booking.tripID == nil else { return nil }
                guard booking.status != .cancelled else { return nil }
                return booking.id
            }
        }
        return assignableBookingIDs(
            bookings: bookings,
            trip: trip,
            now: now,
            upcomingCalendar: upcomingCalendar,
            windowCalendar: windowCalendar
        )
    }

    public func assignableCount(
        bookings: [Booking],
        startDate: Date,
        endDate: Date,
        now: Date = Date(),
        upcomingCalendar: Calendar? = nil,
        windowCalendar: Calendar = HotelStayDate.calendar
    ) -> Int {
        guard endDate >= startDate else { return 0 }
        let draftTrip = Trip(title: "", startDate: startDate, endDate: endDate)
        return assignableBookingIDs(
            bookings: bookings,
            trip: draftTrip,
            now: now,
            upcomingCalendar: upcomingCalendar,
            windowCalendar: windowCalendar
        ).count
    }
}
