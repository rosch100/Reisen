import Foundation

/// Auth-/Session-Surfaces laut Login-HAR (Firefox 2026-08-28) + Live-Refresh 2026-08-28.
public enum BilligerMietwagenAuthConstants {
    public static let portalHost = "billiger-mietwagen.de"
    public static let origin = "https://www.\(portalHost)"
    public static let consumerAPIOrigin = "https://consumer-api.floyt.com"
    public static let floytAPIHostSuffix = ".floyt.com"
    public static let accountPathPrefix = "/reservation/account"

    /// `X-Whitelabel` aus HAR `POST …/auth/v1/login` (nicht Hostname).
    public static let whitelabel = "DE_billiger-mietwagen"

    /// JSON-Feldnamen Session/Refresh (SSOT für Bodies, Codable, Probe).
    public static let accessTokenField = "access_token"
    public static let refreshTokenField = "refresh_token"
    public static let userIDField = "user_id"
    /// Cognito-JWT-Claim; FLOYT erwartet denselben Wert als `user_id` beim Refresh.
    public static let jwtUsernameClaim = "username"

    public static var whitelabelHeaders: [String: String] {
        ["X-Whitelabel": whitelabel]
    }

    public static func bearerAuthorizationHeader(accessToken: String) -> [String: String] {
        ["Authorization": "Bearer \(accessToken)"]
    }

    /// Whitelabel + Bearer für Consumer-API-Calls (Catalog/Detail).
    public static func apiRequestHeaders(accessToken: String) -> [String: String] {
        whitelabelHeaders.merging(bearerAuthorizationHeader(accessToken: accessToken)) { _, new in new }
    }

    /// HAR-SSOT: Login-Endpoint aus Captures; Sync nutzt Cookies + `refreshTokenURL`, nicht diesen Call.
    public static var loginAPIURL: URL {
        consumerURL("/auth/v1/login")
    }

    public static var refreshTokenURL: URL {
        consumerURL("/auth/v1/refresh-token")
    }

    public static var sessionURL: URL {
        portalURL("/user_account/session.php")
    }

    public static var loginPageURL: URL {
        portalURL("\(accountPathPrefix)/login")
    }

    /// Referer für `session.php` während Login-Probe (HAR nach Passwort).
    /// Sync nach Login nutzt bewusst `BilligerMietwagenWebConstants.catalogReferer` (SPA-Katalog).
    public static var sessionProbeReferer: String {
        loginPageURL.absoluteString
    }

    public static func portalURL(_ path: String) -> URL {
        mustURL(origin + path)
    }

    public static func consumerURL(_ path: String) -> URL {
        mustURL(consumerAPIOrigin + path)
    }

    public static func isPortalHost(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == portalHost || h.hasSuffix(".\(portalHost)")
    }

    /// Consumer-API und verwandte `*.floyt.com`-Hosts (z. B. Voucher-URLs).
    public static func isFloytAPIHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if let apiHost = URL(string: consumerAPIOrigin)?.host?.lowercased(), h == apiHost {
            return true
        }
        return h.hasSuffix(floytAPIHostSuffix)
    }

    /// Leere/`[]`-Session-Antworten der Portal-`session.php`.
    public static func isEmptySessionPayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "{}" || trimmed == "[]"
    }

    /// Session-JSON: Sync-Vertrag (`access_token` + `refresh_token` non-empty).
    /// `true`/`false` bei auswertbarem Shape; `nil` bei kaputtem JSON.
    public static func hasSessionTokens(inSessionJSON text: String) -> Bool? {
        do {
            return try BilligerMietwagenTokenPair.parseSession(from: text).hasSessionTokens
        } catch {
            return nil
        }
    }

    static func mustURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Ungültige billiger-mietwagen-URL-Konstante: \(string)")
        }
        return url
    }
}
