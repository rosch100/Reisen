import Foundation
import WebKit
import ReisenProviders

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
            return {
              ok: response.ok,
              status: response.status,
              text: text
            };
            """,
            arguments: [
                "url": url.absoluteString,
                "method": method,
                "headers": headers,
                "bodyB64": bodyB64,
            ],
            contentWorld: .page
        )
        guard let payload = result as? [String: Any] else {
            throw BookingComProviderError.catalogNotFound
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
