import Foundation

extension HotelBasketParser {
    static func joinedGuestName(first: String?, last: String?) -> String? {
        if let first, let last,
           !first.isEmpty, !last.isEmpty,
           !isGuestPlaceholder(first), !isGuestPlaceholder(last) {
            return "\(first) \(last)"
        }
        if let first, !first.isEmpty, !isGuestPlaceholder(first) {
            return first
        }
        if let last, !last.isEmpty, !isGuestPlaceholder(last) {
            return last
        }
        return nil
    }
}
