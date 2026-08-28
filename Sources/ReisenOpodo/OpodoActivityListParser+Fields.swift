import Foundation
import ReisenDomain

extension OpodoActivityListParser {
    func hrefDateGroups(
        from match: NSTextCheckingResult,
        html: String
    ) throws -> (url: String, startRaw: String, endRaw: String)? {
        guard match.numberOfRanges == 4 else { return nil }
        return (
            try extractGroup(html: html, match: match, groupIndex: 1),
            try extractGroup(html: html, match: match, groupIndex: 2),
            try extractGroup(html: html, match: match, groupIndex: 3)
        )
    }

    func extractGroup(html: String, match: NSTextCheckingResult, groupIndex: Int) throws -> String {
        guard let range = Range(match.range(at: groupIndex), in: html) else {
            throw OpodoActivityListParserError.noBookingsFound
        }
        return String(html[range])
    }

    func bookingType(from url: String) -> BookingType? {
        let lower = url.lowercased()
        if lower.contains("hotel") || lower.contains("accommodation") || lower.contains("unterkunft") {
            return .hotel
        }
        if lower.contains("flight") || lower.contains("flug") {
            return .flight
        }
        return nil
    }
}
