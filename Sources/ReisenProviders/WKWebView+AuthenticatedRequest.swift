import Foundation
import WebKit

extension WKWebView {
    /// Builds a `URLRequest` using the same session cookies as the embedded browser.
    public func authenticatedRequest(
        url: URL,
        method: String = "GET",
        accept: String = "application/json, text/html, text/plain, */*",
        referer: String? = nil,
        contentType: String? = nil,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async -> URLRequest {
        var request = AuthenticatedURLRequestBuilder.baseRequest(
            url: url,
            method: method,
            accept: accept,
            referer: referer,
            contentType: contentType,
            body: body,
            headers: headers
        )
        let cookies = await allHTTPCookies()
        AuthenticatedURLRequestBuilder.applyCookieHeader(&request, cookies: cookies, url: url)
        return request
    }

    /// Fetches UTF-8 text with session cookies. Throws on non-2xx or empty body.
    public func fetchAuthenticatedText(
        url: URL,
        method: String = "GET",
        accept: String = "application/json, text/html, text/plain, */*",
        referer: String? = nil,
        contentType: String? = nil,
        body: Data? = nil,
        headers: [String: String] = [:],
        timeoutSeconds: TimeInterval = 60
    ) async throws -> String {
        var request = await authenticatedRequest(
            url: url,
            method: method,
            accept: accept,
            referer: referer,
            contentType: contentType,
            body: body,
            headers: headers
        )
        request.timeoutInterval = timeoutSeconds
        let (data, response) = try await URLSession.shared.data(for: request)
        return try AuthenticatedTextDecode.utf8Text(data: data, response: response)
    }

    /// HTML-Abruf mit Session-Prüfung (HTTP 401/403, Login-Redirect, Login-HTML, optionale Challenge).
    public func fetchAuthenticatedHTML(
        url: URL,
        accept: String = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        referer: String? = nil,
        isLoginHTML: (String) -> Bool,
        isChallengeHTML: ((String) -> Bool)? = nil
    ) async throws -> String {
        let request = await authenticatedRequest(url: url, accept: accept, referer: referer)
        let (data, response) = try await URLSession.shared.data(for: request)
        return try AuthenticatedHTMLSession.validatedUTF8HTML(
            data: data,
            response: response,
            isLoginHTML: isLoginHTML,
            isChallengeHTML: isChallengeHTML
        )
    }
}
