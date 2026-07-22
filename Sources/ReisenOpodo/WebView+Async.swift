import Foundation
import WebKit

extension WKWebView {
    /// Evaluates JavaScript and returns the JSON/string result (best effort).
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

