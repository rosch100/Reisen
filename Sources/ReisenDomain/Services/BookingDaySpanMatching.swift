import Foundation

/// Primitive Tagesvergleiche für `BookingDayOverlap` (SSOT).
public enum BookingDaySpanMatching {
    /// Mehrfachbuchungen am selben Ort mit gleichen Tagesdaten zählen nicht als Überschneidung.
    public static func isSamePlaceAndDates(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = .current
    ) -> Bool {
        guard !a.placeKey.isEmpty, a.placeKey == b.placeKey else { return false }
        return calendar.startOfDay(for: a.startAt) == calendar.startOfDay(for: b.startAt)
            && calendar.startOfDay(for: a.endAt) == calendar.startOfDay(for: b.endAt)
    }

    /// Ende ist exclusive: Abreise-Tag == Anreise-Tag teilt keinen Tag.
    public static func dayRangesOverlap(
        _ a: BookingDaySpan,
        _ b: BookingDaySpan,
        calendar: Calendar = .current
    ) -> Bool {
        let aStart = calendar.startOfDay(for: a.startAt)
        let aEnd = calendar.startOfDay(for: a.endAt)
        let bStart = calendar.startOfDay(for: b.startAt)
        let bEnd = calendar.startOfDay(for: b.endAt)
        return max(aStart, bStart) < min(aEnd, bEnd)
    }
}
