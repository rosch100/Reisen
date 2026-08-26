import Foundation

/// Zuordnung unzugeordneter Buchungen zu Reisen (Trip-Fenster + ab heute).
public enum OpenBookingMatching {
    /// Offene Liste: keine Reise, ab heute, nicht storniert.
    public static func isOpenUnassigned(
        _ booking: SDBooking,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard booking.trip == nil, booking.status != .cancelled else { return false }
        let startOfToday = calendar.startOfDay(for: now)
        return booking.startAt >= startOfToday
    }

    public static func isCandidate(
        _ booking: SDBooking,
        for trip: SDTrip,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard isOpenUnassigned(booking, calendar: calendar, now: now) else { return false }
        let tripStartDay = calendar.startOfDay(for: trip.startDate)
        let tripEndDay = calendar.startOfDay(for: trip.endDate)
        let bookingStartDay = calendar.startOfDay(for: booking.startAt)
        let bookingEndDay = calendar.startOfDay(for: booking.endAt)
        return bookingStartDay >= tripStartDay
            && bookingEndDay <= tripEndDay
    }
}
