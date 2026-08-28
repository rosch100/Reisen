import Foundation
import ReisenDomain

public struct OpodoActivityListParser: Sendable {
    public init() {}

    public func parseBookings(from html: String) throws -> [ProviderBookingDraft] {
        let pattern = #"href="(https?://[^"]+)"[^>]*data-start="([^"]+)"[^>]*data-end="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        return try matches.compactMap { try draft(from: $0, html: html) }
    }
}
