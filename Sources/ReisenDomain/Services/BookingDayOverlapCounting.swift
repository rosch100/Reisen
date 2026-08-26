import Foundation

public enum BookingDayOverlapCounting {
    public static func overlapCount(
        for booking: BookingDaySpan,
        in bookings: [BookingDaySpan],
        calendar: Calendar
    ) -> Int {
        bookings.reduce(0) { partial, other in
            guard other.id != booking.id else { return partial }
            guard !BookingDaySpanMatching.isSamePlaceAndDates(booking, other, calendar: calendar) else {
                return partial
            }
            return BookingDaySpanMatching.dayRangesOverlap(booking, other, calendar: calendar)
                ? partial + 1
                : partial
        }
    }
}
