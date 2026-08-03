import Foundation

extension BookingDetailsParser {
    func parseTotalPriceAmount(from html: String) -> Double? {
        let amountPattern = #"([0-9]{1,3}(?:\.\d{3})*[\,\.]\d{2}|[0-9]+[\,\.]\d{2})"#
        let amountPatternFlexible = #"(?:([0-9]{1,3}(?:\.\d{3})*[\,\.]\d{2}|[0-9]+[\,\.]\d{2}|[0-9]+))"#

        if let amount = effectivePriceFromJSON(html: html, amountPatternFlexible: amountPatternFlexible) {
            return amount
        }
        if let amount = totalPriceInlineColon(html: html, amountPattern: amountPattern) {
            return amount
        }
        return totalPriceHeadlineSeparated(html: html, amountPattern: amountPattern)
    }
}
