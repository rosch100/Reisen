import Foundation
import ReisenDomain

public extension BookingDayOverlap {
    /// UI-Entry: filtert Pool (`isInOverlapPool`), mappt `daySpan`, liefert Partner-IDs (SSOT Domain).
    /// Ohne `elapsedCalendar`: typbewusst je Buchung (Hotel → `HotelStayDate.calendar`).
    static func partnerIDsByID(
        sdBookings: [SDBooking],
        now: Date = Date(),
        elapsedCalendar: Calendar? = nil,
        calendar: Calendar = HotelStayDate.calendar
    ) -> [UUID: [UUID]] {
        let spans = sdBookings
            .filter {
                isInOverlapPool(
                    status: $0.status,
                    endAt: $0.endAt,
                    bookingType: $0.bookingType,
                    now: now,
                    elapsedCalendar: elapsedCalendar
                )
            }
            .map(\.daySpan)
        return partnerIDsByID(
            spans,
            now: now,
            elapsedCalendar: elapsedCalendar,
            calendar: calendar
        )
    }

    /// UI-Entry: Count-Map aus Partner-IDs.
    static func countsByID(
        sdBookings: [SDBooking],
        now: Date = Date(),
        elapsedCalendar: Calendar? = nil,
        calendar: Calendar = HotelStayDate.calendar
    ) -> [UUID: Int] {
        partnerIDsByID(
            sdBookings: sdBookings,
            now: now,
            elapsedCalendar: elapsedCalendar,
            calendar: calendar
        ).mapValues(\.count)
    }
}
