import Foundation
import ReisenDomain

/// Offene Buchung + Reise, die sie als Lückenfüller adressieren kann.
public struct OpenBookingFillCandidate {
    public let booking: SDBooking
    public let trip: SDTrip

    public init(booking: SDBooking, trip: SDTrip) {
        self.booking = booking
        self.trip = trip
    }
}

/// Ergebnis der Offen-Partition: Fill-Kandidaten vs. Rest.
public struct OpenBookingFillPartition {
    public let fillable: [OpenBookingFillCandidate]
    public let other: [SDBooking]

    public init(fillable: [OpenBookingFillCandidate], other: [SDBooking]) {
        self.fillable = fillable
        self.other = other
    }
}

/// Unzugeordnete Buchungen: Offen-Liste, Fill und Seed (Trip-Fenster + ListInclusion).
public enum OpenBookingMatching {
    /// Offen-Liste: keine Reise; `BookingListInclusion` (ab heute oder manuell).
    private static func isListedUnassigned(
        _ booking: SDBooking,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        booking.trip == nil && booking.appearsInList(now: now, calendar: calendar)
    }

    public static func listedUnassigned(
        in bookings: [SDBooking],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [SDBooking] {
        bookings.filter { isListedUnassigned($0, calendar: calendar, now: now) }
    }

    /// Fill/Seed-ohne-Auswahl: listed und ab heute.
    public static func isOpenUnassigned(
        _ booking: SDBooking,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        isListedUnassigned(booking, calendar: calendar, now: now)
            && booking.isUpcoming(now: now, calendar: calendar)
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
        return TripBookingDateWindow.contains(
            bookingStart: booking.startAt,
            bookingEnd: booking.endAt,
            tripStart: trip.startDate,
            tripEnd: trip.endDate,
            calendar: calendar
        )
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
    ) -> OpenBookingFillPartition {
        var hasTimeGapsByTripID: [UUID: Bool] = [:]
        var fillable: [OpenBookingFillCandidate] = []
        var other: [SDBooking] = []
        for booking in bookings {
            if let trip = fillOpportunity(
                booking: booking,
                trips: trips,
                calendar: calendar,
                now: now,
                hasTimeGapsByTripID: &hasTimeGapsByTripID
            ) {
                fillable.append(OpenBookingFillCandidate(booking: booking, trip: trip))
            } else {
                other.append(booking)
            }
        }
        return OpenBookingFillPartition(fillable: fillable, other: other)
    }

    private static func fillOpportunity(
        booking: SDBooking,
        trips: [SDTrip],
        calendar: Calendar,
        now: Date,
        hasTimeGapsByTripID: inout [UUID: Bool]
    ) -> SDTrip? {
        trips
            .filter { isCandidate(booking, for: $0, calendar: calendar, now: now) }
            .filter { hasTimeGaps($0, cache: &hasTimeGapsByTripID) }
            .min(by: earlierTrip)
    }

    private static func hasTimeGaps(_ trip: SDTrip, cache: inout [UUID: Bool]) -> Bool {
        if let cached = cache[trip.id] { return cached }
        let value = trip.completeness().hasTimeGaps
        cache[trip.id] = value
        return value
    }

    private static func earlierTrip(_ lhs: SDTrip, _ rhs: SDTrip) -> Bool {
        if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
