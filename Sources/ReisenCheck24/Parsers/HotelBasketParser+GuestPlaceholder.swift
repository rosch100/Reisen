import Foundation

extension HotelBasketParser {
    static func isGuestPlaceholder(_ s: String?) -> Bool {
        guard let s else { return true }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "-" || trimmed == "—" || trimmed == "–"
    }
}
