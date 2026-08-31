import Foundation
import WebKit

/// Traveloka-Session prüfen, wenn die URL-Heuristik unklar ist (Homepage / Referrer nach Login).
public enum TravelokaSessionProbe {
    public static let whoamiURL = URL(
        string: "\(TravelokaWebConstants.origin)/api/v2/user/whoami"
    )!

    public static func applies(to url: URL) -> Bool {
        guard let host = url.host else { return false }
        return KeychainHostMatching.server(host, matches: "traveloka.com")
    }

    public static func isLoggedIn(fromWhoAmIJSON text: String) -> Bool? {
        TravelokaSessionProbeJSON.isLoggedIn(fromWhoAmIJSON: text)
    }

    public static func whoamiRequestBody(context: TravelokaSessionContext) throws -> Data {
        let payload = context.withSentinel(in: [
            "fields": [] as [Any],
            "data": [:] as [String: Any],
            "clientInterface": TravelokaWebConstants.clientInterface,
        ])
        do {
            return try TravelokaJSONPayload.encode(payload)
        } catch {
            throw TravelokaSessionProbeError.requestBodyEncodingFailed
        }
    }

    public static func whoamiHeaders(context: TravelokaSessionContext) -> [String: String] {
        context.applying(to: [
            "x-domain": "user",
            "x-client-interface": TravelokaWebConstants.clientInterface,
        ])
    }

    public static var signInReferer: String {
        "\(TravelokaWebConstants.origin)/\(TravelokaWebConstants.routePrefix)/user/signin"
    }

    /// Route-Prefix aus Session-URL für whoami-Referer (Fallback: Default-Sign-In).
    public static func signInReferer(routePrefix: String?) -> String {
        guard let routePrefix, !routePrefix.isEmpty else { return signInReferer }
        return "\(TravelokaWebConstants.origin)/\(routePrefix)/user/signin"
    }

    /// whoami mit Session-Cookies (SSOT für Navigation + Session-UI).
    public static func fetchIsLoggedIn(
        using webView: WKWebView,
        additionalHintURLs: [URL] = [],
        timeoutSeconds: TimeInterval = 20
    ) async throws -> Bool? {
        let context = await webView.travelokaSessionContext(additionalHintURLs: additionalHintURLs)
        guard context.hasSentinel else { return nil }
        let text = try await webView.fetchAuthenticatedText(
            url: whoamiURL,
            method: "POST",
            accept: "application/json",
            referer: context.apiReferer(),
            contentType: "application/json",
            body: try whoamiRequestBody(context: context),
            headers: whoamiHeaders(context: context),
            timeoutSeconds: timeoutSeconds
        )
        return isLoggedIn(fromWhoAmIJSON: text)
    }
}

public enum TravelokaSessionProbeError: Error, Sendable {
    case requestBodyEncodingFailed
}
