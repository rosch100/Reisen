import Foundation

/// SSOT: Tages-Überschneidungen zwischen Buchungen (Typ-Occupancy, Ende je nach Typ).
public enum BookingDayOverlap {
    public static func isEligible(status: BookingStatus) -> Bool {
        status != .cancelled
    }

    /// Pool-Mitglied: nicht storniert und nicht abgelaufen (`BookingListInclusion.isElapsed`).
    /// Ohne `elapsedCalendar`: Kalender aus `bookingType` (Hotel → `HotelStayDate.calendar`).
    public static func isInOverlapPool(
        status: BookingStatus,
        endAt: Date,
        bookingType: BookingType,
        now: Date = Date(),
        elapsedCalendar: Calendar? = nil
    ) -> Bool {
        let calendar = elapsedCalendar ?? bookingType.listInclusionCalendar
        return isEligible(status: status)
            && !BookingListInclusion.isElapsed(endAt: endAt, now: now, calendar: calendar)
    }

    /// Partner-IDs je Buchung; Einträge nur wenn mindestens ein Partner.
    /// `elapsedCalendar == nil`: Elapsed je Span über `bookingType.listInclusionCalendar`.
    public static func partnerIDsByID(
        _ bookings: [BookingDaySpan],
        now: Date = Date(),
        elapsedCalendar: Calendar? = nil,
        calendar: Calendar = HotelStayDate.calendar
    ) -> [UUID: [UUID]] {
        let pool = bookings.filter {
            !BookingListInclusion.isElapsed(
                endAt: $0.endAt,
                now: now,
                calendar: elapsedCalendar ?? $0.bookingType.listInclusionCalendar
            )
        }
        guard pool.count >= 2 else { return [:] }

        var result: [UUID: [UUID]] = [:]
        for booking in pool {
            let partners = BookingDayOverlapCounting.overlappingPartnerIDs(
                for: booking,
                in: pool,
                calendar: calendar
            )
            if !partners.isEmpty { result[booking.id] = partners }
        }
        return result
    }

    /// Anzahl überlappender anderer Buchungen pro ID; Einträge nur bei Count > 0.
    public static func countsByID(
        _ bookings: [BookingDaySpan],
        now: Date = Date(),
        elapsedCalendar: Calendar? = nil,
        calendar: Calendar = HotelStayDate.calendar
    ) -> [UUID: Int] {
        partnerIDsByID(
            bookings,
            now: now,
            elapsedCalendar: elapsedCalendar,
            calendar: calendar
        ).mapValues(\.count)
    }
}
