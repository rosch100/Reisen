import Foundation
import ReisenDomain

public extension SDTrip {
    /// Ephemere Completeness aus allen nicht-stornierten Buchungen (nicht `timelineBookings`).
    func completeness(minGap: TimeInterval = 12 * 60 * 60) -> TripCompleteness {
        let bookings = resolvedBookings
            .filter { $0.status != .cancelled }
            .map(DomainMapper.booking(from:))
        return TripCompletenessCalculator.evaluate(
            tripStart: startDate,
            tripEnd: endDate,
            bookings: bookings,
            minGap: minGap
        )
    }

    /// Inter-Gap-Count für Listen, nur bei aktuellen Reisen mit Lücken; sonst `nil`.
    func listGapBadgeCount(
        calendar: Calendar = .current,
        now: Date = Date(),
        minGap: TimeInterval = 12 * 60 * 60
    ) -> Int? {
        guard endDate >= calendar.startOfDay(for: now) else { return nil }
        let summary = completeness(minGap: minGap)
        guard summary.hasTimeGaps else { return nil }
        return summary.interBookingGapCount
    }

    /// Listen-Badge nur für aktuelle Reisen mit Inter-Booking-Lücken.
    func showsListGapBadge(
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        listGapBadgeCount(calendar: calendar, now: now) != nil
    }
}
