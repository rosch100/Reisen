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

    /// Sidebar Trip-Outline: current nutzt Timeline; elapsed alle nicht-stornierten Zuordnungen.
    func sidebarOutlineBookings(
        isElapsed: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SDBooking] {
        if isElapsed {
            return resolvedBookings
                .filter { $0.status != .cancelled }
                .sorted { $0.startAt < $1.startAt }
        }
        return timelineBookings(now: now, calendar: calendar)
    }
}
