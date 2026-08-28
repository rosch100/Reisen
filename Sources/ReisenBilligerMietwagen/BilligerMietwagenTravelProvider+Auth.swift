import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

extension BilligerMietwagenTravelProvider {
    /// Session → Refresh (`user_id` = JWT-Claim `jwtUsernameClaim`) → Session-POST → Access-Token.
    func requireAccessToken(webView: WKWebView) async throws -> String {
        progress("Prüfe Session")
        let tokens = try await loadSessionTokens(webView: webView)
        guard let userID = BilligerMietwagenAccessToken.userID(fromAccessToken: tokens.access) else {
            throw BilligerMietwagenProviderError.tokenRefreshFailed
        }

        progress("Erneuere Session")
        let refreshed = try await refreshTokens(
            webView: webView,
            refreshToken: tokens.refresh,
            userID: userID
        )
        // Pflicht: rotierten Refresh in die Cookie-Session schreiben, sonst scheitert der nächste Sync.
        try await persistSessionTokens(
            webView: webView,
            accessToken: refreshed.access,
            refreshToken: refreshed.refresh
        )
        return refreshed.access
    }

    private func loadSessionTokens(webView: WKWebView) async throws -> (access: String, refresh: String) {
        let session = try BilligerMietwagenTokenPair.parseSession(
            from: try await fetchJSON(
                webView: webView,
                url: BilligerMietwagenAuthConstants.sessionURL,
                referer: BilligerMietwagenWebConstants.catalogReferer
            )
        )
        return try session.requiringSessionTokens()
    }

    private func refreshTokens(
        webView: WKWebView,
        refreshToken: String,
        userID: String
    ) async throws -> (access: String, refresh: String) {
        let refreshed = try BilligerMietwagenTokenPair.parseRefresh(
            from: try await postJSON(
                webView: webView,
                url: BilligerMietwagenAuthConstants.refreshTokenURL,
                referer: BilligerMietwagenWebConstants.catalogReferer,
                headers: BilligerMietwagenAuthConstants.whitelabelHeaders,
                body: try jsonBody([
                    BilligerMietwagenAuthConstants.refreshTokenField: refreshToken,
                    BilligerMietwagenAuthConstants.userIDField: userID,
                ])
            )
        )
        return try refreshed.requiringRefreshedTokens()
    }

    private func persistSessionTokens(
        webView: WKWebView,
        accessToken: String,
        refreshToken: String
    ) async throws {
        _ = try await postJSON(
            webView: webView,
            url: BilligerMietwagenAuthConstants.sessionURL,
            referer: BilligerMietwagenWebConstants.catalogReferer,
            body: try jsonBody([
                BilligerMietwagenAuthConstants.accessTokenField: accessToken,
                BilligerMietwagenAuthConstants.refreshTokenField: refreshToken,
            ])
        )
    }

    private func jsonBody(_ object: [String: String]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
}
