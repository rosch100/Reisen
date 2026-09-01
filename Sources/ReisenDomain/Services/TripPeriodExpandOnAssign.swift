import Foundation

/// Vorschlag, den Reisezeitraum zu erweitern, bevor eine Buchung außerhalb des Fensters zugewiesen wird.
public enum TripPeriodExpandOnAssign {
    public struct Proposal: Equatable, Sendable {
        public let start: Date
        public let end: Date

        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }

    /// `nil` wenn die Buchung bereits im Reisezeitraum liegt; sonst Union der Kalendertage.
    public static func proposalIfNeeded(
        bookingStart: Date,
        bookingEnd: Date,
        tripStart: Date,
        tripEnd: Date,
        calendar: Calendar = .current
    ) -> Proposal? {
        proposalIfNeeded(
            bookings: [(bookingStart, bookingEnd)],
            tripStart: tripStart,
            tripEnd: tripEnd,
            calendar: calendar
        )
    }

    /// `nil` wenn alle Buchungen im Fenster liegen; sonst Union Trip ∪ alle Buchungen (Kalendertage).
    public static func proposalIfNeeded(
        bookings: [(start: Date, end: Date)],
        tripStart: Date,
        tripEnd: Date,
        calendar: Calendar = .current
    ) -> Proposal? {
        guard !bookings.isEmpty else { return nil }
        let anyOutside = bookings.contains { booking in
            !TripBookingDateWindow.contains(
                bookingStart: booking.start,
                bookingEnd: booking.end,
                tripStart: tripStart,
                tripEnd: tripEnd,
                calendar: calendar
            )
        }
        guard anyOutside else { return nil }

        var startDay = calendar.startOfDay(for: tripStart)
        var endDay = calendar.startOfDay(for: tripEnd)
        for booking in bookings {
            let bookingStartDay = calendar.startOfDay(for: booking.start)
            let bookingEndDay = calendar.startOfDay(for: booking.end)
            if bookingStartDay < startDay { startDay = bookingStartDay }
            if bookingEndDay > endDay { endDay = bookingEndDay }
        }
        return Proposal(start: startDay, end: endDay)
    }
}
