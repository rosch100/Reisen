import Foundation

extension OpodoCancellationDeadlineParser {
    func normalizeGermanLongDatePart(_ datePart: String) -> String {
        datePart
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func tokenizeGermanLongDate(_ normalized: String) -> [Substring] {
        var s = normalized

        // Tag/Monat trennen: "1.Aug." → "1. Aug."
        if let r = try? NSRegularExpression(
            pattern: #"(?i)(\d{1,2}\.?)\s*([A-Za-zÄÖÜäöü]{2,}\.?)"#
        ) {
            s = r.stringByReplacingMatches(
                in: s,
                options: [],
                range: NSRange(location: 0, length: (s as NSString).length),
                withTemplate: "$1 $2"
            )
        }

        // Monat/Jahr trennen: "Aug.2026" → "Aug. 2026"
        if let r = try? NSRegularExpression(
            pattern: #"(?i)([A-Za-zÄÖÜäöü]{2,}\.?)\s*(\d{4})"#
        ) {
            s = r.stringByReplacingMatches(
                in: s,
                options: [],
                range: NSRange(location: 0, length: (s as NSString).length),
                withTemplate: "$1 $2"
            )
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
    }
}
