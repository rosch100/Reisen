import Foundation
import WebKit
import ReisenProviders

extension WKWebView {
    /// Evaluates JavaScript and returns the result as string (best effort).
    func evaluateJavaScriptStringAsync(_ javaScript: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javaScript) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let stringResult = result as? String {
                    continuation.resume(returning: stringResult)
                } else {
                    continuation.resume(returning: result.map { String(describing: $0) })
                }
            }
        }
    }
}

/// Helper methods for calling Airbnb GraphQL/REST endpoints from within the WKWebView page context,
/// so cookies are automatically included (Airlock/Arkose remains inside the web view).
extension WKWebView {
    /// Same-origin `fetch` inside the page context (cookies + WAF context).
    /// This mirrors `BookingComTravelProvider`'s approach and avoids cookie/token export complexity.
    func airbnbFetchTextAsync(url: URL, headers: [String: String]) async throws -> String {
        let result = try await callAsyncJavaScript(
            """
            const init = {
              method: 'GET',
              credentials: 'include',
              headers: headers
            };
            const response = await fetch(url, init);
            const text = await response.text();
            return {
              ok: response.ok,
              status: response.status,
              text: text
            };
            """,
            arguments: [
                "url": url.absoluteString,
                "headers": headers,
            ],
            contentWorld: .page
        )
        guard let payload = result as? [String: Any] else {
            throw NSError(
                domain: "AirbnbFetch",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected fetch payload"]
            )
        }
        let ok: Bool = {
            if let value = payload["ok"] as? Bool { return value }
            if let number = payload["ok"] as? NSNumber { return number.boolValue }
            return false
        }()
        let status: Int = {
            if let value = payload["status"] as? Int { return value }
            if let number = payload["status"] as? NSNumber { return number.intValue }
            return -1
        }()
        let text = (payload["text"] as? String) ?? ""
        guard ok else {
            throw AuthenticatedFetchError.httpStatus(status)
        }
        guard !text.isEmpty else {
            throw AuthenticatedFetchError.emptyBody
        }
        return text
    }
}
