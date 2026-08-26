import Foundation
import ReisenDomain

extension HotelBookingPriceResolver {
    static func isSameHotelStay(_ a: ParsedBooking, _ b: ParsedBooking) -> Bool {
        guard a.type == .hotel, b.type == .hotel else { return false }
        let aTitle = (a.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bTitle = (b.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !aTitle.isEmpty, aTitle == bTitle else { return false }

        let calendar = Calendar.current
        return calendar.isDate(a.startAt, inSameDayAs: b.startAt)
            && calendar.isDate(a.endAt, inSameDayAs: b.endAt)
    }
}
