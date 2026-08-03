import Foundation

/// SSOT: Tages-Überschneidungen zwischen Buchungen (Ende exclusive am Kalendertag).
public enum BookingDayOverlap {
    /// Anzahl überlappender anderer Buchungen pro ID; Einträge nur bei Count > 0.
    public static func countsByID(
        _ bookings: [BookingDaySpan],
        calendar: Calendar = .current
    ) -> [UUID: Int] {
        guard bookings.count >= 2 else { return [:] }

        var counts: [UUID: Int] = [:]
        for booking in bookings {
            let overlapCount = BookingDayOverlapCounting.overlapCount(
                for: booking,
                in: bookings,
                calendar: calendar
            )
            if overlapCount > 0 { counts[booking.id] = overlapCount }
        }
        return counts
    }
}
