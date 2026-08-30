import Foundation

public extension SDTrip {
    var resolvedBookings: [SDBooking] { bookings ?? [] }
    var resolvedGaps: [SDGap] { gaps ?? [] }

    /// Timeline: ab heute, nicht storniert; manuell importierte Buchungen auch in der Vergangenheit.
    func timelineBookings(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SDBooking] {
        return resolvedBookings
            .filter { $0.appearsInList(now: now, calendar: calendar) }
            .sorted { $0.startAt < $1.startAt }
    }
}
