import Foundation
import ReisenDomain

/// Extrahiert Zimmer-/Verpflegungsdaten aus Booking.com Confirmation-HTML.
public struct BookingComHotelConfirmationParser: Sendable {
    public init() {}

    public func parseRateDetails(from html: String) -> BookingRateDetails? {
        let roomCategory = parseRoomCategory(from: html)
        let guestCount = parseGuestCount(from: html)
        let breakfast = parseBreakfastIncluded(from: html)

        guard roomCategory != nil || guestCount != nil || breakfast != nil else {
            return nil
        }

        return BookingRateDetails(
            roomCategory: roomCategory,
            boardType: breakfast == true ? .breakfastIncluded : .unknown,
            includedBreakfast: breakfast,
            guestCount: guestCount
        )
    }
}

private extension BookingComHotelConfirmationParser {
    func parseRoomCategory(from html: String) -> String? {
        let patterns = [
            #"alt="([^"]*zimmer[^"]*)""#,
            #"room-info-card__content-header[^>]*>\s*<[^>]+>\s*([^<]+)"#,
            #"<h[1-3][^>]*>\s*([^<]*[Zz]immer[^<]*)\s*</h"#,
        ]
        for pattern in patterns {
            if let match = BookingComParsing.capture(pattern, in: html, options: [.caseInsensitive]) {
                let trimmed = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    func parseGuestCount(from html: String) -> Int? {
        if let adults = BookingComParsing.capture(#""adults"\s*:\s*['"]?(\d+)"#, in: html),
           let childrenRaw = BookingComParsing.capture(#""children"\s*:\s*['"]?(\d+)"#, in: html),
           let adultsCount = Int(adults),
           let childrenCount = Int(childrenRaw) {
            let total = adultsCount + childrenCount
            return total > 0 ? total : nil
        }
        if let match = BookingComParsing.capture(#"(\d+)\s+Erwachsene"#, in: html),
           let adults = Int(match) {
            return adults
        }
        return nil
    }

    func parseBreakfastIncluded(from html: String) -> Bool? {
        let lower = html.lowercased()
        if lower.contains("frühstück ist im endpreis inbegriffen")
            || lower.contains("breakfast is included")
            || lower.contains("frühstück inbegriffen") {
            return true
        }
        if lower.contains("ohne frühstück") || lower.contains("room only") {
            return false
        }
        return nil
    }
}
