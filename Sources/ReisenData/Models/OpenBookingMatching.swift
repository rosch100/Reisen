import Foundation
import ReisenDomain

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

    public static func openUnassigned(
        in bookings: [SDBooking],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [SDBooking] {
        bookings.filter { isOpenUnassigned($0, calendar: calendar, now: now) }
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

    /// Erste Candidate-Reise mit Inter-Booking-Lücken (frühste `startDate`, dann `id`).
    public static func fillOpportunity(
        booking: SDBooking,
        trips: [SDTrip],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> SDTrip? {
        var hasTimeGapsByTripID: [UUID: Bool] = [:]
        return fillOpportunity(
            booking: booking,
            trips: trips,
            calendar: calendar,
            now: now,
            hasTimeGapsByTripID: &hasTimeGapsByTripID
        )
    }

    /// Partition offener Buchungen: Fill-Kandidaten vs. Rest (SSOT für Offen-UI).
    /// Completeness pro Reise einmal berechnen (kein N×M-GapDetector).
    public static func partitionByFillOpportunity(
        bookings: [SDBooking],
        trips: [SDTrip],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> (fillable: [(booking: SDBooking, trip: SDTrip)], other: [SDBooking]) {
        var hasTimeGapsByTripID: [UUID: Bool] = [:]
        var fillable: [(booking: SDBooking, trip: SDTrip)] = []
        var other: [SDBooking] = []
        for booking in bookings {
            if let trip = fillOpportunity(
                booking: booking,
                trips: trips,
                calendar: calendar,
                now: now,
                hasTimeGapsByTripID: &hasTimeGapsByTripID
            ) {
                fillable.append((booking, trip))
            } else {
                other.append(booking)
            }
        }
        return (fillable, other)
    }

    private static func fillOpportunity(
        booking: SDBooking,
        trips: [SDTrip],
        calendar: Calendar,
        now: Date,
        hasTimeGapsByTripID: inout [UUID: Bool]
    ) -> SDTrip? {
        let matches = trips
            .filter { isCandidate(booking, for: $0, calendar: calendar, now: now) }
            .filter { trip in
                if let cached = hasTimeGapsByTripID[trip.id] {
                    return cached
                }
                let hasGaps = trip.completeness().hasTimeGaps
                hasTimeGapsByTripID[trip.id] = hasGaps
                return hasGaps
            }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        return matches.first
    }
}
