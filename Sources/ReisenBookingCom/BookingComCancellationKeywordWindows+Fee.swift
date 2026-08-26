import Foundation

extension BookingComCancellationDeadlineParser {
    func extractFeeAmount(from snippet: String) -> Double? {
        let patterns = [
            #"gebühr\s*[:=]?\s*(?:€|EUR)?\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            #"(?:€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
        ]
        for pattern in patterns {
            if let number = BookingComParsing.capture(pattern, in: snippet) {
                return Double(number.replacingOccurrences(of: ",", with: "."))
            }
        }
        return nil
    }

    func cleanedPolicyText(_ raw: String) -> String {
        var text = BookingComParsing.normalizeEuroEntities(raw)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
