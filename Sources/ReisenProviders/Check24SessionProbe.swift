import Foundation
import WebKit

/// Check24-Session prüfen, wenn die URL-Heuristik unklar ist (Homepage nach SSO).
/// SSOT: Activities-API/-Seite für Probe und `Check24TravelProvider`.
public enum Check24SessionProbe {
    public static let activitiesAPIURL = URL(string: "https://kundenbereich.check24.de/kb/api/activities")!
    public static let activitiesPageURL = URL(string: "https://kundenbereich.check24.de/user/account/activities.html")!
    private static let maxAttempts = 3

    public static func applies(to url: URL) -> Bool {
        guard let host = url.host else { return false }
        return isCheck24Host(host)
    }

    public static func isLoggedIn(fromActivitiesResponse text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }
        return root["activities"] != nil
    }

    /// GET Activities-API mit Session-Cookies. Retries wie Sync; 401/403 → nicht angemeldet.
    public static func fetchIsLoggedIn(
        using webView: WKWebView,
        timeoutSeconds: TimeInterval = 20
    ) async throws -> Bool {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let text = try await webView.fetchAuthenticatedText(
                    url: activitiesAPIURL,
                    accept: "application/json, text/html, text/plain, */*",
                    referer: activitiesPageURL.absoluteString,
                    timeoutSeconds: timeoutSeconds
                )
                if AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(text) {
                    return false
                }
                return isLoggedIn(fromActivitiesResponse: text)
            } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
                return false
            } catch let error as CancellationError {
                throw error
            } catch {
                lastError = error
                guard attempt < maxAttempts else { break }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
            }
        }
        throw lastError ?? AuthenticatedFetchError.emptyBody
    }

    private static func isCheck24Host(_ host: String) -> Bool {
        KeychainHostMatching.server(host, matches: "check24.de")
            || KeychainHostMatching.server(host, matches: "check24.com")
    }
}
