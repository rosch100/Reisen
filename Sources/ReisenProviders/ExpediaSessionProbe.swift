import Foundation
import WebKit

/// Expedia.de Session: Cookie `EG_SESSIONTOKEN` + `GET /trips` ohne Login-HTML.
public enum ExpediaSessionProbe {
    public static let origin = "https://www.expedia.de"
    public static let portalHost = "expedia.de"
    public static let tripsURL = URL(string: "\(origin)/trips")!
    public static let sessionCookieName = "EG_SESSIONTOKEN"
    public static let duaidCookieName = "DUAID"

    public static func isPortalHost(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == portalHost || h.hasSuffix("." + portalHost)
    }

    public static func applies(to url: URL) -> Bool {
        guard let host = url.host else { return false }
        return isPortalHost(host)
    }

    public static func isManageBookingURL(_ url: URL?) -> Bool {
        guard let url, let host = url.host, isPortalHost(host) else { return false }
        return url.path.lowercased().contains("/manage-booking")
    }

    public static func hasSessionToken(cookies: [HTTPCookie]) -> Bool {
        cookies.contains {
            $0.name.caseInsensitiveCompare(sessionCookieName) == .orderedSame
                && !$0.value.isEmpty
        }
    }

    public static func duaid(from cookies: [HTTPCookie]) -> String? {
        cookies.first {
            $0.name.caseInsensitiveCompare(duaidCookieName) == .orderedSame
                && !$0.value.isEmpty
        }?.value
    }

    public static func isLoginHTML(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("/login") && lower.contains("password")
            || lower.contains("initialauthform")
            || lower.contains("arkoselabs")
    }

    /// Live-Probe für Hub/Ampel: Session-Cookie und Trips-HTML ohne Login-Redirect.
    public static func fetchIsLoggedIn(
        using webView: WKWebView
    ) async throws -> Bool? {
        let cookies = await webView.allHTTPCookies()
        guard hasSessionToken(cookies: cookies) else { return false }
        do {
            _ = try await webView.fetchAuthenticatedHTML(
                url: tripsURL,
                referer: origin + "/",
                isLoginHTML: isLoginHTML
            )
            return true
        } catch AuthenticatedSessionError.notEstablished {
            return false
        }
    }
}
