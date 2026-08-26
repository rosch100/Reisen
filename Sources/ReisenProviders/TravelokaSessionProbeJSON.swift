import Foundation

/// Parse Traveloka `whoami` JSON for session probe (SSOT).
public enum TravelokaSessionProbeJSON {
    public static func isLoggedIn(fromWhoAmIJSON text: String) -> Bool? {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        guard let dataObj = root["data"] as? [String: Any] else {
            return nil
        }
        if let revoked = dataObj["revoked"] as? Bool, revoked {
            return false
        }
        // Logged-in payload always includes loginMethod (TV, AP, GM, …).
        // `id` allein reicht nicht — anonyme/teilweise Payloads ohne Session.
        if let method = dataObj["loginMethod"] as? String, !method.isEmpty {
            return true
        }
        return false
    }
}
