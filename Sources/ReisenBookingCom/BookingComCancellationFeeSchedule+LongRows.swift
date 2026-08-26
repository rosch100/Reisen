import Foundation
import ReisenDomain

extension BookingComCancellationDeadlineParser {
    func parseLongGermanFeeRows(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        guard let regex = longGermanFeeRowRegex() else { return [] }
        let ns = html as NSString
        var deadlines: [CancellationDeadline] = []
        regex.enumerateMatches(in: html, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            if let deadline = longGermanFeeDeadline(match: match, html: ns, hotelOffsetSeconds: hotelOffsetSeconds) {
                deadlines.append(deadline)
            }
        }
        return deadlines
    }

    func longGermanFeeRowRegex() -> NSRegularExpression? {
        try? NSRegularExpression(
            // DE: bis/ab 10. August … — EN: until/from 10 August …
            pattern: #"(bis|ab|until|from)\s+(\d{1,2}\.?\s*[A-Za-zÄÖÜäöüß]+?\s+\d{4})\s+(\d{2}:\d{2}).{0,400}?(?:€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
    }

    func longGermanFeeDeadline(
        match: NSTextCheckingResult?,
        html: NSString,
        hotelOffsetSeconds: Int
    ) -> CancellationDeadline? {
        guard let match, match.numberOfRanges >= 5 else { return nil }
        let prefix = html.substring(with: match.range(at: 1)).lowercased()
        let datePart = html.substring(with: match.range(at: 2))
        let timePart = html.substring(with: match.range(at: 3))
        let amountRaw = html.substring(with: match.range(at: 4))
        guard let amount = Double(amountRaw.replacingOccurrences(of: ",", with: ".")),
              let deadlineAt = BookingComParsing.parseGermanLongDateTime(
                in: "\(datePart) \(timePart)",
                offsetSeconds: hotelOffsetSeconds
              ) else {
            return nil
        }
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
