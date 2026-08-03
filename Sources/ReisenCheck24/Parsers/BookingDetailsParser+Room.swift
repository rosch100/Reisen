import Foundation

extension BookingDetailsParser {
    func parseRoomCountAndCategory(from html: String) -> (roomCount: Int?, roomCategory: String?) {
        // Beispiele:
        // <div class="...-roomName"><strong><span><strong>1x Doppelzimmer</strong></span></strong></div>
        // <div class="...-roomTitle">1x Bungalow</div>
        let patterns = [
            #"roomName[^>]*>.*?<strong>\s*([0-9]+)\s*x\s*([^<]+?)\s*</strong>"#,
            #"roomTitle[^>]*>\s*([0-9]+)\s*x\s*([^<]+?)\s*<"#,
        ]

        for pattern in patterns {
            let parsed = accumulateRoomMatches(pattern: pattern, in: html)
            if parsed.totalRooms > 0 {
                let category = parsed.categories.isEmpty ? nil : parsed.categories.joined(separator: " + ")
                return (parsed.totalRooms, category)
            }
        }
        return (nil, nil)
    }
}
