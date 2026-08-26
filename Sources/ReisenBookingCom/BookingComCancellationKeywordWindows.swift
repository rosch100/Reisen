import Foundation
import ReisenDomain

/// Keyword-/Snippet-Heuristik wenn kein Fee-Schedule lesbar ist.
extension BookingComCancellationDeadlineParser {
    func parseKeywordWindows(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        let keywords = [
            "kostenlos stornieren", "kostenlose stornierung",
            "free cancellation", "free_cancellation",
            "haveTimeLeftForFreeCancellation",
            "stornogebühr", "cancellation fee",
        ]
        let lower = html.lowercased()
        var deadlines: [CancellationDeadline] = []

        for keyword in keywords {
            var searchStart = lower.startIndex
            while let range = lower.range(of: keyword, options: [], range: searchStart..<lower.endIndex) {
                let windowRadius = 160
                let start = lower.index(range.lowerBound, offsetBy: -windowRadius, limitedBy: lower.startIndex) ?? lower.startIndex
                let end = lower.index(range.upperBound, offsetBy: windowRadius, limitedBy: lower.endIndex) ?? lower.endIndex
                let snippet = String(html[start..<end])
                let normalizedSnippet = BookingComParsing.normalizeEuroEntities(snippet)
                let snippetLower = normalizedSnippet.lowercased()

                guard let date = deadlineDate(from: normalizedSnippet, hotelOffsetSeconds: hotelOffsetSeconds) else {
                    searchStart = range.upperBound
                    continue
                }

                let amount = extractFeeAmount(from: normalizedSnippet)
                let isFree = amount == 0
                    || snippetLower.contains("free cancellation")
                    || snippetLower.contains("free_cancellation")
                    || snippetLower.contains("kostenlos")
                    || (amount == nil && (snippetLower.contains("kostenlos") || snippetLower.contains("free")))

                deadlines.append(
                    CancellationDeadline(
                        deadlineAt: date,
                        policyText: cleanedPolicyText(normalizedSnippet),
                        isStrict: true,
                        isFreeCancellation: isFree,
                        hotelOffsetSeconds: hotelOffsetSeconds,
                        cancellationFeeAmount: amount ?? (isFree ? 0 : nil)
                    )
                )
                searchStart = range.upperBound
            }
        }
        return deadlines
    }
}
