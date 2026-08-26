import Foundation

public extension SDTrip {
    var resolvedBookings: [SDBooking] { bookings ?? [] }
    var resolvedGaps: [SDGap] { gaps ?? [] }

    /// Aktive Timeline-Buchungen: ab heute, nicht storniert, nach Start sortiert.
    func timelineBookings(
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SDBooking] {
        let startOfToday = calendar.startOfDay(for: now)
        return resolvedBookings
            .filter { $0.startAt >= startOfToday && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
    }
}
