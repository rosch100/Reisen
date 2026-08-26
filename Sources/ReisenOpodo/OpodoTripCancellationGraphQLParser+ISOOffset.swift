import Foundation

extension OpodoTripCancellationGraphQLParser {
    /// Offset aus ISO-Suffix (`Z`, `±HH:MM`, `±HHMM`). Fehlt → nil.
    func isoOffsetSeconds(in raw: String) -> Int? {
        if raw.hasSuffix("Z") || raw.hasSuffix("z") { return 0 }
        guard let regex = try? NSRegularExpression(
            pattern: #"([+-])(\d{2}):?(\d{2})$"#
        ) else { return nil }
        let ns = raw as NSString
        guard let match = regex.firstMatch(
            in: raw,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges == 4 else { return nil }
        let sign = ns.substring(with: match.range(at: 1)) == "-" ? -1 : 1
        guard let hours = Int(ns.substring(with: match.range(at: 2))),
              let minutes = Int(ns.substring(with: match.range(at: 3))) else { return nil }
        return sign * (hours * 3600 + minutes * 60)
    }

    func dateFromEpochMillis(_ raw: Int64) -> Date? {
        Date(timeIntervalSince1970: TimeInterval(raw) / 1000)
    }
}
