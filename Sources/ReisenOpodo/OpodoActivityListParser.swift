import Foundation
import ReisenDomain

public struct OpodoActivityListParser: Sendable {
    public init() {}

    public func parseBookings(from html: String) throws -> [ProviderBookingDraft] {
        let pattern = #"href="(https?://[^"]+)"[^>]*data-start="([^"]+)"[^>]*data-end="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        var bookings: [ProviderBookingDraft] = []
        for match in matches {
            if let draft = draft(from: match, html: html) {
                bookings.append(draft)
            }
        }

        if bookings.isEmpty {
            throw OpodoActivityListParserError.noBookingsFound
        }

        return bookings
    }
}
