import Foundation

/// Primitive Tagesvergleiche für `BookingDayOverlap` (SSOT).
public enum BookingDaySpanMatching {
    public static func isSamePlaceAndDates(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = HotelStayDate.calendar
    ) -> Bool {
        guard !a.placeKey.isEmpty, a.placeKey == b.placeKey else { return false }
        return calendar.startOfDay(for: a.startAt) == calendar.startOfDay(for: b.startAt)
            && calendar.startOfDay(for: a.endAt) == calendar.startOfDay(for: b.endAt)
    }

    /// Mehrfachzimmer: Same-Place+Same-Dates nur innerhalb derselben Reise unterdrücken.
    public static func shouldSuppressAsMultiRoom(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = HotelStayDate.calendar
    ) -> Bool {
        guard let tripA = a.tripID, let tripB = b.tripID, tripA == tripB else { return false }
        return isSamePlaceAndDates(a, b, calendar: calendar)
    }

    /// Belegungsintervall half-open; leer wenn `endDay < startDay`.
    public static func occupiedRange(
        _ span: BookingDaySpan,
        calendar: Calendar = HotelStayDate.calendar
    ) -> (start: Date, endExclusive: Date)? {
        let startDay = calendar.startOfDay(for: span.startAt)
        let endDay = calendar.startOfDay(for: span.endAt)
        guard endDay >= startDay else { return nil }
        // Stay-artig: Checkout exclusive. startDay == endDay → 0 Nächte (leeres Intervall).
        if span.bookingType.usesStayLikeOverlapEnd {
            return (startDay, endDay)
        }
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) else {
            return nil
        }
        return (startDay, endExclusive)
    }

    public static func dayRangesOverlap(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = HotelStayDate.calendar
    ) -> Bool {
        guard let ao = occupiedRange(a, calendar: calendar),
              let bo = occupiedRange(b, calendar: calendar) else {
            return false
        }
        return max(ao.start, bo.start) < min(ao.endExclusive, bo.endExclusive)
    }
}
