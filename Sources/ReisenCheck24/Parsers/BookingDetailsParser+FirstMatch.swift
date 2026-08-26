import Foundation

extension BookingDetailsParser {
    func parseFirstMatch(forKeyOrLabel label: String, in html: String) -> String? {
        // fail-soft: versucht Schlüssel/Label sowohl in eingebettetem JSON
        // als auch im Klartext (Label: value) zu finden.
        let escaped = NSRegularExpression.escapedPattern(for: label)

        // JSON-Key:  "airline":"...".
        let jsonPattern = "\"\(escaped)\"\\s*:\\s*\"([^\"]+)\""
        if let match = firstRegexMatch(pattern: jsonPattern, in: html) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Text-Label: Airline: Lufthansa
        let textPattern = "\(escaped)\\s*[:\\-]\\s*([^<]{3,80})"
        if let match = firstRegexMatch(pattern: textPattern, in: html) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
