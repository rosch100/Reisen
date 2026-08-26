import Foundation

extension BookingComHotelConfirmationParser {
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
}
