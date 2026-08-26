import Foundation

extension BookingDetailsParser {
    func priceDecimalSeparator(
        lastComma: String.Index?,
        lastDot: String.Index?
    ) -> Character {
        if let comma = lastComma, let dot = lastDot {
            return comma > dot ? "," : "."
        }
        if lastComma != nil { return "," }
        return "."
    }
}
