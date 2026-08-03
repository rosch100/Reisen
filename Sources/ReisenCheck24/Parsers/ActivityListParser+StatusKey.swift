import Foundation
import ReisenDomain

extension ActivityListParser {
    func activityStatusKey(from activity: [String: Any]) -> String {
        if let status = activity["status"] as? [String: Any],
           let key = status["key"] as? String {
            return key.lowercased()
        }
        return ""
    }
}
