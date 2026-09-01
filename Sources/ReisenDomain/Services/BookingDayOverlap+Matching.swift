import Foundation

public extension BookingDayOverlap {
    static func isSamePlaceAndDates(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = HotelStayDate.calendar
    ) -> Bool {
        BookingDaySpanMatching.isSamePlaceAndDates(a, b, calendar: calendar)
    }

    static func shouldSuppressAsMultiRoom(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = HotelStayDate.calendar
    ) -> Bool {
        BookingDaySpanMatching.shouldSuppressAsMultiRoom(a, b, calendar: calendar)
    }

    static func dayRangesOverlap(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = HotelStayDate.calendar
    ) -> Bool {
        BookingDaySpanMatching.dayRangesOverlap(a, b, calendar: calendar)
    }
}
