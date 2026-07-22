import Foundation
import WebKit

extension WKWebView {
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

    /// Same-origin `fetch` inside the page (cookies, WAF, Capla context) — preferred for Booking GraphQL.
    func fetchInPageText(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> String {
        let bodyB64 = body.map { $0.base64EncodedString() } ?? ""
        let result = try await callAsyncJavaScript(
            """
            const init = {
              method: method,
              credentials: 'include',
              headers: headers
            };
            if (bodyB64 && bodyB64.length > 0) {
              const binary = atob(bodyB64);
              const bytes = new Uint8Array(binary.length);
              for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
              init.body = bytes;
            }
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
                "method": method,
                "headers": headers,
                "bodyB64": bodyB64,
            ],
            contentWorld: .page
        )
        guard let text = result as? String, !text.isEmpty else {
            throw BookingComProviderError.catalogNotFound
        }
        return text
    }
}
