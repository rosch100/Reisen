import Foundation

extension BookingComHotelConfirmationParser {
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
