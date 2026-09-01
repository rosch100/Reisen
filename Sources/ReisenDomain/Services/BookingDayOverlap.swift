import Foundation

/// SSOT: Tages-Überschneidungen zwischen Buchungen (Typ-Occupancy, Ende je nach Typ).
public enum BookingDayOverlap {
    public static func isEligible(status: BookingStatus) -> Bool {
        status != .cancelled
    }

    /// Anzahl überlappender anderer Buchungen pro ID; Einträge nur bei Count > 0.
    public static func countsByID(
        _ bookings: [BookingDaySpan],
        calendar: Calendar = HotelStayDate.calendar
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
