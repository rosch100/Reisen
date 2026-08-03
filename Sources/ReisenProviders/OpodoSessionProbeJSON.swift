import Foundation

/// Parse `GetUserAccount` GraphQL-JSON für Opodo-Session-Probe (SSOT).
public enum OpodoSessionProbeJSON {
    public static func isLoggedIn(fromGraphQLJSON text: String) -> Bool? {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        if let errors = root["errors"] as? [Any], !errors.isEmpty {
            return false
        }
        guard let dataObj = root["data"] as? [String: Any],
              let account = dataObj["userAccount"] as? [String: Any]
        else {
            return nil
        }
        return account["isLoggedIn"] as? Bool
    }
}
