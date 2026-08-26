import Foundation

extension BookingDetailsParser {
    func parseFirstInteger(forLabels labels: [String], in html: String) -> Int? {
        let escapedLabels = labels.map { NSRegularExpression.escapedPattern(for: $0) }
        let joined = escapedLabels.joined(separator: "|")

        // Beispiele:
        // "Reisende: 2"
        // "Pax 2"
        let pattern = "(?:\\b(?:\(joined))\\b)[^0-9]{0,20}([0-9]+)"
        guard let match = firstRegexMatch(pattern: pattern, in: html) else { return nil }
        return Int(match)
    }
}
