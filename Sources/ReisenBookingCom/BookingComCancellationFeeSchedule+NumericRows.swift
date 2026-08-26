import Foundation
import ReisenDomain

extension BookingComCancellationDeadlineParser {
    func parseNumericGermanFeeRows(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        guard let regex = numericGermanFeeRowRegex() else { return [] }
        let ns = html as NSString
        var deadlines: [CancellationDeadline] = []
        regex.enumerateMatches(in: html, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            if let deadline = numericGermanFeeDeadline(match: match, html: ns, hotelOffsetSeconds: hotelOffsetSeconds) {
                deadlines.append(deadline)
            }
        }
        return deadlines
    }

    func numericGermanFeeRowRegex() -> NSRegularExpression? {
        try? NSRegularExpression(
            pattern: #"(?:bis|ab)?\s*(\d{2}\.\d{2}\.\d{4})(?:\s+(\d{2}:\d{2}))?.{0,120}?(?:€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
    }

    func numericGermanFeeDeadline(
        match: NSTextCheckingResult?,
        html: NSString,
        hotelOffsetSeconds: Int
    ) -> CancellationDeadline? {
        guard let match, match.numberOfRanges >= 4 else { return nil }
        let datePart = html.substring(with: match.range(at: 1))
        let timePart = match.range(at: 2).location != NSNotFound
            ? html.substring(with: match.range(at: 2))
            : "23:59"
        let amountRaw = html.substring(with: match.range(at: 3))
        guard let amount = Double(amountRaw.replacingOccurrences(of: ",", with: ".")),
              let deadlineAt = BookingComParsing.parseGermanDateTime(
                "\(datePart) \(timePart)",
                offsetSeconds: hotelOffsetSeconds
              ) else {
            return nil
        }
        let matched = html.substring(with: match.range).lowercased()
        let prefix = matched.contains("ab ") || matched.hasPrefix("ab") ? "ab" : "bis"
        return CancellationDeadline(
            deadlineAt: deadlineAt,
            policyText: feePolicyText(prefix: prefix, datePart: datePart, timePart: timePart, amount: amount),
            isStrict: true,
            isFreeCancellation: amount == 0,
            hotelOffsetSeconds: hotelOffsetSeconds,
            cancellationFeeAmount: amount
        )
    }
}
