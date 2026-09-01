import Foundation

public enum BookingDayOverlapCounting {
    public static func overlappingPartnerIDs(
        for booking: BookingDaySpan,
        in bookings: [BookingDaySpan],
        calendar: Calendar = HotelStayDate.calendar
    ) -> [UUID] {
        bookings.compactMap { other in
            guard other.id != booking.id else { return nil }
            guard !BookingDaySpanMatching.shouldSuppressAsMultiRoom(
                booking,
                other,
                calendar: calendar
            ) else {
                return nil
            }
            return BookingDaySpanMatching.dayRangesOverlap(booking, other, calendar: calendar)
                ? other.id
                : nil
        }
    }

    public static func overlapCount(
        for booking: BookingDaySpan,
        in bookings: [BookingDaySpan],
        calendar: Calendar = HotelStayDate.calendar
    ) -> Int {
        overlappingPartnerIDs(for: booking, in: bookings, calendar: calendar).count
    }
}
