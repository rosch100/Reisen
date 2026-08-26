import Foundation

extension OpodoCancellationDeadlineParser {
    func parseGermanDayMonthYear(_ input: String) -> (Int, Int, Int)? {
        // Erwartet grob: „<day>[.] <monthToken>[.] <year>“
        // Beispiel: „1 August 2026“, „1. Aug. 2026“, „01 März 2026“
        // Nutzt Unicode Buchstabenklasse, damit auch ungewöhnliche Token (z. B. „Mär“)
        // ohne Spezial-Casing sicher gematcht werden.
        let pattern = #"(?i)^\s*(\d{1,2})\.?\s*([\p{L}]{2,})\s*\.?\s*(\d{4})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = input as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: input, options: [], range: fullRange),
              match.numberOfRanges >= 4,
              let dayRange = Range(match.range(at: 1), in: input),
              let monthRange = Range(match.range(at: 2), in: input),
              let yearRange = Range(match.range(at: 3), in: input),
              let day = Int(input[dayRange]),
              let year = Int(input[yearRange]) else { return nil }

        let monthToken = String(input[monthRange]).lowercased().replacingOccurrences(of: ".", with: "")

        if let month = Self.monthByToken[monthToken] {
            return (day, month, year)
        }
        return nil
    }
}
