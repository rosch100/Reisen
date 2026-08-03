import Foundation

extension HotelBasketParser {
    static func guestDisplayName(first: String?, last: String?) -> String? {
        let first = first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = last?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(isGuestPlaceholder(first) && isGuestPlaceholder(last)) else { return nil }
        return joinedGuestName(first: first, last: last)
    }
}
