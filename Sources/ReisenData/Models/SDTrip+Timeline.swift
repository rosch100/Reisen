import Foundation

public extension SDTrip {
    var resolvedBookings: [SDBooking] { bookings ?? [] }
    var resolvedGaps: [SDGap] { gaps ?? [] }

    /// Timeline: ab heute, nicht storniert; manuell importierte Buchungen auch in der Vergangenheit.
    /// Ohne `calendar`: jede Buchung nutzt typbewussten Default (`SDBooking.listInclusionCalendar`).
    func timelineBookings(
        now: Date = Date(),
        calendar: Calendar? = nil
    ) -> [SDBooking] {
        return resolvedBookings
            .filter { $0.appearsInList(now: now, calendar: calendar) }
            .sorted { $0.startAt < $1.startAt }
    }

    /// Sidebar-Kindzeilen einer Reise.
    /// Aktuell: Timeline. Abgelaufen: alle nicht-stornierten Buchungen (inkl. vergangener Provider-Buchungen).
    func sidebarChildBookings(
        tripIsElapsed: Bool,
        now: Date = Date(),
        calendar: Calendar? = nil
    ) -> [SDBooking] {
        if tripIsElapsed {
            return resolvedBookings
                .filter { $0.status != .cancelled }
                .sorted { $0.startAt < $1.startAt }
        }
        return timelineBookings(now: now, calendar: calendar)
    }
}
