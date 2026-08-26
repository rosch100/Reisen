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
        OpodoSessionProbeJSON.isLoggedIn(fromGraphQLJSON: text)
    }
}
