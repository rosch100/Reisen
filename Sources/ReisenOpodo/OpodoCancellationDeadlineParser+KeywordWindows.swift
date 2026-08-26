import Foundation
import ReisenDomain

extension OpodoCancellationDeadlineParser {
    func parseKeywordWindows(from html: String) -> [CancellationDeadline] {
        let lower = html.lowercased()
        let keywords: [String] = [
            "stornierungsrichtlinie",
            "storno",
            "stornieren",
            "stornierbar",
            "kostenlos",
            "free cancellation",
            "refund",
            "cancel",
            "cancelation",
            "until",
            "bis",
        ]

        var deadlines: [CancellationDeadline] = []
        for keyword in keywords {
            var searchStart = lower.startIndex
            while let range = lower.range(of: keyword, options: [], range: searchStart..<lower.endIndex) {
                let windowRadius = 350
                let start = lower.index(range.lowerBound, offsetBy: -windowRadius, limitedBy: lower.startIndex) ?? lower.startIndex
                let end = lower.index(range.upperBound, offsetBy: windowRadius, limitedBy: lower.endIndex) ?? lower.endIndex
                let snippet = String(html[start..<end])

                if let date = firstDateInSnippet(snippet) {
                    deadlines.append(
                        CancellationDeadline(
                            deadlineAt: date,
                            policyText: snippet.trimmingCharacters(in: .whitespacesAndNewlines),
                            isStrict: true,
                            isFreeCancellation: isFreeCancellation(in: snippet),
                            // Opodo-UI-Zeiten sind Wall-Clock (HAR oft `-00:00`), nicht Geräte-TZ.
                            hotelOffsetSeconds: 0,
                            cancellationFeeAmount: extractFeeAmount(from: snippet)
                        )
                    )
                }
                searchStart = range.upperBound
            }
        }
        return deadlines
    }
}
