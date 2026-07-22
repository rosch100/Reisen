import WebKit
import Foundation

extension WKWebView {
    /// Async-Hülle um `evaluateJavaScript`, gezielt für String-Rückgaben.
    func evaluateJavaScriptStringAsync(_ javaScriptString: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javaScriptString) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as? String)
                }
            }
        }
    }

    /// Bool-Auswertung; bei JS-Fehlern `false` statt Exception (Sync soll nicht an JS scheitern).
    func evaluateJavaScriptBoolAsync(_ javaScriptString: String) async -> Bool {
        await withCheckedContinuation { continuation in
            evaluateJavaScript(javaScriptString) { result, error in
                if error != nil {
                    continuation.resume(returning: false)
                    return
                }
                let isTrue: Bool = {
                    if let b = result as? Bool { return b }
                    if let n = result as? NSNumber { return n.boolValue }
                    if let s = result as? String { return (s as NSString).boolValue }
                    return false
                }()
                continuation.resume(returning: isTrue)
            }
        }
    }

    /// Wartet, bis eine JS-Bedingung in der Seite `true` ergibt.
    func waitForJavaScriptCondition(
        _ conditionJavaScriptString: String,
        timeoutSeconds: TimeInterval = 20,
        pollIntervalSeconds: TimeInterval = 0.25
    ) async -> Bool {
        let start = Date()
        while true {
            if await evaluateJavaScriptBoolAsync(conditionJavaScriptString) { return true }
            if Date().timeIntervalSince(start) > timeoutSeconds { return false }
            try? await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
        }
    }
}
