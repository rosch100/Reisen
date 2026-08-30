import Foundation
import ReisenDomain

public extension SDBooking {
    func appearsInList(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        BookingListInclusion.appearsInList(
            startAt: startAt,
            status: status,
            provider: provider,
            now: now,
            calendar: calendar
        )
    }

    func isUpcoming(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        BookingListInclusion.isUpcoming(
            startAt: startAt,
            now: now,
            calendar: calendar
        )
    }

    func isElapsed(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        BookingListInclusion.isElapsed(
            endAt: endAt,
            now: now,
            calendar: calendar
        )
    }
}
