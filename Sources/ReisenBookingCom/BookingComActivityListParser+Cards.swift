import Foundation
import ReisenDomain

extension BookingComActivityListParser {
    func parseDataAttributeCards(from html: String) throws -> [ProviderBookingDraft] {
        let pattern = #"href="(https?://[^"]+)"[^>]*data-start="([^"]+)"[^>]*data-end="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        var bookings: [ProviderBookingDraft] = []
        for match in matches {
            guard match.numberOfRanges == 4,
                  let url = group(html, match, 1),
                  let startRaw = group(html, match, 2),
                  let endRaw = group(html, match, 3),
                  let startAt = parseDate(startRaw),
                  let endAt = parseDate(endRaw) else { continue }
            if let draft = draft(url: url, startAt: startAt, endAt: endAt) {
                bookings.append(draft)
            }
        }
        return bookings
    }
}
