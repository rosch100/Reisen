import Foundation
import WebKit

extension WKWebView {
    /// Liest alle Cookies aus dem WebsiteDataStore des WebViews.
    func allHTTPCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    /// Baut einen `URLRequest` mit denselben Session-Cookies wie der eingebettete Browser.
    func authenticatedRequest(
        url: URL,
        accept: String = "application/json, text/plain, */*",
        referer: String? = "https://kundenbereich.check24.de/user/account/activities.html"
    ) async -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }

        let cookies = await allHTTPCookies()
        let matching = cookies.filter { cookie in
            cookieMatches(cookie, url: url)
        }
        if !matching.isEmpty {
            let header = matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
        return request
    }

    private func cookieMatches(_ cookie: HTTPCookie, url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        // Domain-Match: cookie für check24.de gilt auch für kundenbereich.check24.de
        return host == domain || host.hasSuffix("." + domain) || host.hasSuffix(domain)
    }
}
