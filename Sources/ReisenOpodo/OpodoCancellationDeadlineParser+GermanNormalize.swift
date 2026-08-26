import Foundation

extension OpodoCancellationDeadlineParser {
    func removeTrailingMonthDot(_ normalized: String) -> String {
        let pattern = #"(?i)(\b[A-Za-zÄÖÜäöü]{3,})\."#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return normalized }
        let ns = normalized as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(in: normalized, options: [], range: fullRange, withTemplate: "$1")
    }

    func ensureLeadingDayDot(_ normalizedWithoutMonthDot: String) -> String {
        let pattern = #"^(\d{1,2})(\s+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return normalizedWithoutMonthDot
        }
        let ns = normalizedWithoutMonthDot as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        if regex.firstMatch(in: normalizedWithoutMonthDot, options: [], range: fullRange) != nil,
           !normalizedWithoutMonthDot.contains(".") {
            return regex.stringByReplacingMatches(
                in: normalizedWithoutMonthDot,
                options: [],
                range: fullRange,
                withTemplate: "$1.$2"
            )
        }

        return normalizedWithoutMonthDot
    }
}
