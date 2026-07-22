import Foundation

/// Opodo-Session prüfen, wenn die URL-Heuristik unklar ist (Homepage nach Login).
/// SSOT: dieselbe GetUserAccount-Query wie `OpodoTravelProvider`.
public enum OpodoSessionProbe {
    public static let graphqlURL = URL(string: "https://www.opodo.de/frontend-api/service/graphql")!

    public static func applies(to url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "opodo.de" || host.hasSuffix(".opodo.de")
    }

    /// JSON-Body für GetUserAccount (gleiche Query wie Sync-Session-Check).
    public static func getUserAccountRequestBody() -> Data {
        Data(
            #"{"query":"query GetUserAccount($userAccountRequest: UserAccountRequest) { userAccount(userAccountRequest: $userAccountRequest) { isLoggedIn email } }","operationName":"GetUserAccount"}"#
                .utf8
        )
    }

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
