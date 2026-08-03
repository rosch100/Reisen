import Foundation

extension BookingDetailsParser {
    func accumulateRoomMatches(
        pattern: String,
        in html: String
    ) -> (totalRooms: Int, categories: [String]) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return (0, [])
        }
        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: fullRange)

        var totalRooms = 0
        var categories: [String] = []
        for match in matches {
            guard let parsed = roomMatchParts(match: match, html: html) else { continue }
            totalRooms += parsed.count
            if let category = parsed.category {
                categories.append(category)
            }
        }
        return (totalRooms, categories)
    }
}
