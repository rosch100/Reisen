import Foundation
import ReisenDomain

extension BookingComActivityListParser {
    /// Embedded reservation-like JSON often present in SSR My Trips pages.
    func parseJSONLDOrEmbeddedReservations(from html: String) throws -> [ProviderBookingDraft] {
        let pattern = #""(?:booking_url|bookUrl|confirmation_url|url)"\s*:\s*"(https?://[^"]+booking\.com[^"]+)"[\s\S]{0,800}?"(?:checkin|check_in|startDate|arrival)"\s*:\s*"([^"]+)"[\s\S]{0,400}?"(?:checkout|check_out|endDate|departure)"\s*:\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
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
