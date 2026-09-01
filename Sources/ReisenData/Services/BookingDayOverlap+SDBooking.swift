import Foundation
import ReisenDomain

public extension BookingDayOverlap {
    /// UI-Entry: filtert cancelled, mappt `daySpan`, zählt Overlaps (SSOT Domain).
    static func countsByID(
        sdBookings: [SDBooking],
        calendar: Calendar = HotelStayDate.calendar
    ) -> [UUID: Int] {
        let spans = sdBookings
            .filter { isEligible(status: $0.status) }
            .map(\.daySpan)
        return countsByID(spans, calendar: calendar)
    }
}
