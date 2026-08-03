import Foundation

extension BookingDetailsParser {
    func parseAmountText(_ raw: String) -> Double? {
        let lastComma = raw.lastIndex(of: ",")
        let lastDot = raw.lastIndex(of: ".")

        guard lastComma != nil || lastDot != nil else {
            // JSON kann auch integerbeträge enthalten (z.B. "235" statt "235.00").
            return Double(raw)
        }

        let decimalSeparator = priceDecimalSeparator(lastComma: lastComma, lastDot: lastDot)
        let thousandSeparator: Character = decimalSeparator == "," ? "." : ","

        let normalized = raw
            .replacingOccurrences(of: String(thousandSeparator), with: "")
            .replacingOccurrences(of: String(decimalSeparator), with: ".")

        return Double(normalized)
    }
}
