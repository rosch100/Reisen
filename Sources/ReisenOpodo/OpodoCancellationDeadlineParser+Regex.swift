import Foundation

extension OpodoCancellationDeadlineParser {
    func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange) else { return nil }
        let rangeIndex = match.numberOfRanges > 1 ? 1 : 0
        let range = match.range(at: rangeIndex)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range)
    }

    func extractFeeAmount(from snippet: String) -> Double? {
        let patterns: [String] = [
            #"(\€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            #"fee\s*[:=]?\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            #"gebühr\s*[:=]?\s*(?:\€|EUR)?\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: snippet),
               let number = firstMatch(pattern: #"[0-9]+(?:[.,][0-9]{1,2})?"#, in: match) {
                let normalized = number.replacingOccurrences(of: ",", with: ".")
                return Double(normalized)
            }
        }
        return nil
    }
}
