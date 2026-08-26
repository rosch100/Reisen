import Foundation
import ReisenDomain

extension OpodoCancellationDeadlineParser {
    func parseStornierungsrichtlinieLines(in text: String) -> [CancellationDeadline] {
        // Label optional/mit Whitespace: „Stornierungsrichtlinie Bis 1. August 2026 (Bis 22:00)“
        // Punkt nach Tag optional (UI/i18n: „1. August“ oder „1 August“).
        let patterns = [
            // Monatsabkürzungen können einen Punkt enthalten: „Aug.“ statt „August“.
            // Zusätzlich: zwischen Monat und Jahr kann Opodo auch ohne Whitespace rendern (robuster).
            #"(?i)Stornierungsrichtlinie\s+Bis\s+(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})(?:\s*\(\s*Bis\s+(\d{1,2}:\d{2})\s*\))?"#,
            #"(?i)(?:^|[\n\r])\s*Bis\s+(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})(?:\s*\(\s*Bis\s+(\d{1,2}:\d{2})\s*\))?"#,
        ]

        var result: [CancellationDeadline] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let ns = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let dateRange = Range(match.range(at: 1), in: text) else { continue }
                let datePart = String(text[dateRange])
                var timePart: String?
                if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound,
                   let timeRange = Range(match.range(at: 2), in: text) {
                    timePart = String(text[timeRange])
                }
                guard let deadlineAt = parseGermanLongDate(datePart, time: timePart) else { continue }
                let policyRange = Range(match.range, in: text)
                let policyText = policyRange.map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
                let labeled = (policyText ?? "").localizedCaseInsensitiveContains("Stornierungsrichtlinie")
                result.append(
                    CancellationDeadline(
                        deadlineAt: deadlineAt,
                        policyText: labeled ? policyText : "Stornierungsrichtlinie \(policyText ?? datePart)",
                        isStrict: true,
                        isFreeCancellation: true,
                        hotelOffsetSeconds: 0,
                        cancellationFeeAmount: nil
                    )
                )
            }
        }
        return result
    }
}
