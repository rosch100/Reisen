import Foundation
import ReisenDomain

extension OpodoCancellationDeadlineParser {
    func parseKeywordWindows(from html: String) -> [CancellationDeadline] {
        let lower = html.lowercased()
        let keywords: [String] = [
            "cancellation policy",
            "free cancellation",
            "free cancel",
            "refund",
            "cancelation",
            "until",
            "cancel",
        ]

        var deadlines: [CancellationDeadline] = []
        for keyword in keywords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            var searchStart = lower.startIndex
            while searchStart < lower.endIndex {
                let searchRange = NSRange(searchStart..<lower.endIndex, in: lower)
                guard let match = regex.firstMatch(in: lower, options: [], range: searchRange),
                      let swiftRange = Range(match.range, in: lower)
                else {
                    break
                }
                let windowRadius = 350
                let start = lower.index(swiftRange.lowerBound, offsetBy: -windowRadius, limitedBy: lower.startIndex) ?? lower.startIndex
                let end = lower.index(swiftRange.upperBound, offsetBy: windowRadius, limitedBy: lower.endIndex) ?? lower.endIndex
                let snippet = String(html[start..<end])

                if let parsed = firstDateInSnippet(snippet) {
                    deadlines.append(
                        CancellationDeadline(
                            deadlineAt: parsed.date,
                            policyText: snippet.trimmingCharacters(in: .whitespacesAndNewlines),
                            isStrict: true,
                            isFreeCancellation: isFreeCancellation(in: snippet),
                            hotelOffsetSeconds: parsed.offsetSeconds,
                            cancellationFeeAmount: extractFeeAmount(from: snippet)
                        )
                    )
                }
                searchStart = swiftRange.upperBound
            }
        }
        return deadlines
    }
}
