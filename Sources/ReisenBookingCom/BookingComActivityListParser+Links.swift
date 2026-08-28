import Foundation
import ReisenDomain

extension BookingComActivityListParser {
    /// Fallback: reservation/confirmation links with nearby ISO dates.
    func parseMyTripsLinks(from html: String) throws -> [ProviderBookingDraft] {
        let linkPattern = #"href="(https?://(?:secure\.)?booking\.com/[^"]*(?:confirmation|mytrips|reservation|hotel)[^"]*)""#
        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]) else {
            return []
        }
        let ns = html as NSString
        let matches = linkRegex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        var bookings: [ProviderBookingDraft] = []
        let datePattern = #"(\d{4}-\d{2}-\d{2})"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern, options: []) else { return [] }

        for match in matches {
            guard let url = group(html, match, 1) else { continue }
            let windowStart = max(0, match.range.location - 400)
            let windowEnd = min(ns.length, match.range.location + match.range.length + 800)
            let window = ns.substring(with: NSRange(location: windowStart, length: windowEnd - windowStart))
            let dateMatches = dateRegex.matches(in: window, options: [], range: NSRange(window.startIndex..., in: window))
            let dates = dateMatches.compactMap { m -> Date? in
                guard let raw = group(window, m, 1) else { return nil }
                return ISODateTime.parse(raw)
            }
            guard dates.count >= 2 else { continue }
            if let draft = draft(url: url, startAt: dates[0], endAt: dates[1]) {
                bookings.append(draft)
            }
        }
        return bookings
    }
}
