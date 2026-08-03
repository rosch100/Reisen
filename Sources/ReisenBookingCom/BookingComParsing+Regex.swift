import Foundation

extension BookingComParsing {
    /// First capture group of `pattern`, or nil.
    static func capture(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        captures(pattern, in: text, options: options).first
    }

    /// Capture groups 1…n (empty strings omitted only when range missing).
    static func captures(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: full) else { return [] }
        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            let range = match.range(at: index)
            guard range.location != NSNotFound else { continue }
            groups.append(ns.substring(with: range))
        }
        return groups
    }

    static func normalizeEuroEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&euro;", with: "€", options: [.caseInsensitive])
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}
