import Foundation
import WebKit
import ReisenProviders

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
        referer: String? = Check24SessionProbe.activitiesPageURL.absoluteString
    ) async -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }

        let cookies = await allHTTPCookies()
        let matching = cookies.filter { HTTPCookieHostMatching.matches($0, url: url) }
        if !matching.isEmpty {
            let header = matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
        return request
    }
}
