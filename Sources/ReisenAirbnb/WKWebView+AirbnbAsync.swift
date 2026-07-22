import Foundation
import WebKit

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
            if (!response.ok) {
              throw new Error('HTTP ' + response.status + ': ' + text.slice(0, 180));
            }
            if (!text) {
              throw new Error('empty body');
            }
            return text;
            """,
            arguments: [
                "url": url.absoluteString,
                "headers": headers,
            ],
            contentWorld: .page
        )
        guard let text = result as? String, !text.isEmpty else {
            throw NSError(domain: "AirbnbFetch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty response text"])
        }
        return text
    }
}

