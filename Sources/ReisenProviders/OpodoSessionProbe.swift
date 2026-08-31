import Foundation
import WebKit

/// Opodo-Session prüfen, wenn die URL-Heuristik unklar ist (Homepage nach Login).
/// SSOT: dieselbe GetUserAccount-Query wie `OpodoTravelProvider`.
public enum OpodoSessionProbe {
    public static let graphqlURL = URL(string: "https://www.opodo.de/frontend-api/service/graphql")!
    public static let homepageReferer = "https://www.opodo.de/"

    public static func applies(to url: URL) -> Bool {
        guard let host = url.host else { return false }
        return KeychainHostMatching.server(host, matches: "opodo.de")
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

    /// GraphQL GetUserAccount mit Session-Cookies (SSOT für Navigation + Session-UI).
    public static func fetchIsLoggedIn(
        using webView: WKWebView,
        timeoutSeconds: TimeInterval = 20
    ) async throws -> Bool? {
        let text = try await webView.fetchAuthenticatedText(
            url: graphqlURL,
            method: "POST",
            accept: "application/json",
            referer: homepageReferer,
            contentType: "application/json",
            body: getUserAccountRequestBody(),
            timeoutSeconds: timeoutSeconds
        )
        return isLoggedIn(fromGraphQLJSON: text)
    }
}
