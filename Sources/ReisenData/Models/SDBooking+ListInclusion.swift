import Foundation
import ReisenDomain

public extension SDBooking {
    /// Typbewusster Default: Hotel → `HotelStayDate.calendar`, sonst `Calendar.current`.
    var listInclusionCalendar: Calendar {
        bookingType.listInclusionCalendar
    }

    func appearsInList(
        now: Date = Date(),
        calendar: Calendar? = nil
    ) -> Bool {
        BookingListInclusion.appearsInList(
            startAt: startAt,
            status: status,
            provider: provider,
            now: now,
            calendar: calendar ?? listInclusionCalendar
        )
    }

    func isUpcoming(
        now: Date = Date(),
        calendar: Calendar? = nil
    ) -> Bool {
        BookingListInclusion.isUpcoming(
            startAt: startAt,
            now: now,
            calendar: calendar ?? listInclusionCalendar
        )
    }

    func isElapsed(
        now: Date = Date(),
        calendar: Calendar? = nil
    ) -> Bool {
        BookingListInclusion.isElapsed(
            endAt: endAt,
            now: now,
            calendar: calendar ?? listInclusionCalendar
        )
    }
}
