import Foundation

extension BookingDetailsParser {
    func firstRegexMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return (text as NSString).substring(with: range)
    }

    func firstRegexMatchGroups(
        pattern: String,
        in text: String,
        expectedGroups: Int
    ) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange) else { return nil }
        guard match.numberOfRanges == expectedGroups + 1 else { return nil }

        var results: [String] = []
        for i in 1...expectedGroups {
            let range = match.range(at: i)
            guard range.location != NSNotFound else { return nil }
            results.append((text as NSString).substring(with: range))
        }
        return results
    }
}
