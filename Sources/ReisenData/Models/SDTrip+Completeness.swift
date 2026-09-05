import Foundation
import ReisenDomain

public extension SDTrip {
    /// Ephemere Completeness aus allen Trip-Buchungen (nicht `timelineBookings`).
    /// Cancelled filtert `TripCompletenessCalculator` (SSOT).
    func completeness() -> TripCompleteness {
        TripCompletenessCalculator.evaluate(
            tripStart: startDate,
            tripEnd: endDate,
            bookings: resolvedBookings.map(DomainMapper.booking(from:))
        )
    }

    /// Inter-Gap-Count für Listen, nur bei aktuellen Reisen mit Lücken; sonst `nil`.
    func listGapBadgeCount(
        calendar: Calendar = HotelStayDate.calendar,
        now: Date = Date()
    ) -> Int? {
        guard endDate >= calendar.startOfDay(for: now) else { return nil }
        let count = completeness().interBookingGapCount
        return count > 0 ? count : nil
    }

    /// Einmal pro Liste: Trip-ID → Inter-Gap-Count (nur Einträge mit Badge).
    static func listGapBadgeCounts(
        for trips: [SDTrip],
        calendar: Calendar = HotelStayDate.calendar,
        now: Date = Date()
    ) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        result.reserveCapacity(trips.count)
        for trip in trips {
            if let count = trip.listGapBadgeCount(calendar: calendar, now: now) {
                result[trip.id] = count
            }
        }
        return result
    }
}
