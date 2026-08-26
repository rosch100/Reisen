import Foundation

public extension BookingDayOverlap {
    static func isSamePlaceAndDates(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = .current
    ) -> Bool {
        BookingDaySpanMatching.isSamePlaceAndDates(a, b, calendar: calendar)
    }

    static func dayRangesOverlap(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = .current
    ) -> Bool {
        BookingDaySpanMatching.dayRangesOverlap(a, b, calendar: calendar)
    }
}
