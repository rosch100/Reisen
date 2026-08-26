import Foundation

extension ActivityListParser {
    func parseGermanOrEnglishAmount(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let decimalSeparator = amountDecimalSeparator(in: cleaned)
        let thousandSeparator: Character = decimalSeparator == "," ? "." : ","
        let normalized = cleaned
            .replacingOccurrences(of: String(thousandSeparator), with: "")
            .replacingOccurrences(of: String(decimalSeparator), with: ".")
        return Double(normalized)
    }
}
