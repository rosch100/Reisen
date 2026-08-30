import Foundation
import ReisenDomain

public extension SDTrip {
    func isElapsed(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        BookingListInclusion.isElapsed(
            endAt: endDate,
            now: now,
            calendar: calendar
        )
    }
}
