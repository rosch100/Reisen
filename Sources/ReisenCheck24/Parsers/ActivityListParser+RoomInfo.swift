import Foundation

extension ActivityListParser {
    func activityRoomInfo(from activity: [String: Any]) -> (count: Int?, category: String?) {
        let psd = productSpecificData(from: activity)
        guard let trimmed = jsonString(psd, "sso_room_text", "ssoRoomText") else {
            return (nil, nil)
        }
        return parseRoomInfoText(trimmed)
    }
}
