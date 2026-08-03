import Foundation

extension ActivityListParser {
    func activityRoomInfo(from activity: [String: Any]) -> (count: Int?, category: String?) {
        let psd = productSpecificData(from: activity)
        let raw = (psd["sso_room_text"] as? String)
            ?? (psd["ssoRoomText"] as? String)
            ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }
        return parseRoomInfoText(trimmed)
    }
}
