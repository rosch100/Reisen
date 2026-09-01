import Foundation

public enum BookingDayOverlapCounting {
    public static func overlapCount(
        for booking: BookingDaySpan,
        in bookings: [BookingDaySpan],
        calendar: Calendar = HotelStayDate.calendar
    ) -> Int {
        bookings.reduce(0) { partial, other in
            guard other.id != booking.id else { return partial }
            guard !BookingDaySpanMatching.shouldSuppressAsMultiRoom(
                booking,
                other,
                calendar: calendar
            ) else {
                return partial
            }
            return BookingDaySpanMatching.dayRangesOverlap(booking, other, calendar: calendar)
                ? partial + 1
                : partial
        }
    }
}
