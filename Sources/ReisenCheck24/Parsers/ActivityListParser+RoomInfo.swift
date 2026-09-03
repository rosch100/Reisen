import Foundation

extension ActivityListParser {
    func activityRoomInfo(from activity: [String: Any]) -> (count: Int?, category: String?) {
        let psd = productSpecificData(from: activity)
        if let trimmed = jsonString(psd, "sso_room_text", "ssoRoomText") {
            return parseRoomInfoText(trimmed)
        }
        // Hotel-KB ohne PSD-Room-Text: Zimmertyp steht oft in detail.line2.
        guard let line2 = catalogDetailLine2(from: activity),
              Check24CatalogDetailLine.looksLikeRoomCategory(line2) else {
            return (nil, nil)
        }
        return (nil, line2)
    }
}
