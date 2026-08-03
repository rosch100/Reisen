import Foundation
import ReisenDomain

extension OpodoActivityListParser {
    func extractGroup(html: String, match: NSTextCheckingResult, groupIndex: Int) throws -> String {
        guard let range = Range(match.range(at: groupIndex), in: html) else {
            throw OpodoActivityListParserError.noBookingsFound
        }
        return String(html[range])
    }

    func bookingType(from url: String) -> BookingType {
        let lower = url.lowercased()
        if lower.contains("hotel") || lower.contains("accommodation") || lower.contains("unterkunft") {
            return .hotel
        }
        if lower.contains("flight") || lower.contains("flug") {
            return .flight
        }
        return .other
    }
}
