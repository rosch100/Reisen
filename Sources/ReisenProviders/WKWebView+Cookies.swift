import Foundation
import WebKit

extension WKWebView {
    /// Reads all cookies from the WebView's website data store.
    public func allHTTPCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

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
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = body

        let cookies = await allHTTPCookies()
        let matching = cookies.filter { cookieMatches($0, url: url) }
        if !matching.isEmpty {
            let header = matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
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
        headers: [String: String] = [:]
    ) async throws -> String {
        let request = await authenticatedRequest(
            url: url,
            method: method,
            accept: accept,
            referer: referer,
            contentType: contentType,
            body: body,
            headers: headers
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw AuthenticatedFetchError.httpStatus(status)
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw AuthenticatedFetchError.emptyBody
        }
        return text
    }

    private func cookieMatches(_ cookie: HTTPCookie, url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return host == domain || host.hasSuffix("." + domain) || host.hasSuffix(domain)
    }
}

public enum AuthenticatedFetchError: LocalizedError, Sendable {
    case httpStatus(Int)
    case emptyBody

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "Authentifizierter Abruf fehlgeschlagen (HTTP \(code))."
        case .emptyBody:
            return "Authentifizierter Abruf lieferte keinen Text."
        }
    }
}
