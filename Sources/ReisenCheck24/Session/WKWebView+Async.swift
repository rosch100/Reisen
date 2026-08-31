import WebKit
import Foundation
import ReisenAppCore

enum JavaScriptConditionResult: Equatable, Sendable {
    case succeeded
    case javaScriptError
    case timedOut
    case cancelled
}

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
        pollIntervalSeconds: TimeInterval = 0.25,
        onPollStarted: (() -> Void)? = nil
    ) async -> JavaScriptConditionResult {
        let start = Date()
        var lastJavaScriptError: Error?
        var didSignalStart = false
        while true {
            if Task.isCancelled {
                await recordConditionEvent(
                    result: .cancelled,
                    durationMilliseconds: elapsedMilliseconds(since: start),
                    reason: "task_cancelled"
                )
                return .cancelled
            }
            if !didSignalStart {
                onPollStarted?()
                didSignalStart = true
            }
            do {
                let value = try await evaluateJavaScriptConditionAsync(conditionJavaScriptString)
                lastJavaScriptError = nil
                if value {
                    await recordConditionEvent(
                        result: .succeeded,
                        durationMilliseconds: elapsedMilliseconds(since: start),
                        reason: "condition_true"
                    )
                    return .succeeded
                }
            } catch {
                lastJavaScriptError = error
            }
            if Date().timeIntervalSince(start) > timeoutSeconds {
                if let lastJavaScriptError {
                    await recordConditionEvent(
                        result: .failed,
                        durationMilliseconds: elapsedMilliseconds(since: start),
                        reason: DiagnosticRedactor.redact(lastJavaScriptError.localizedDescription)
                    )
                    return .javaScriptError
                }
                await recordConditionEvent(
                    result: .timedOut,
                    durationMilliseconds: elapsedMilliseconds(since: start),
                    reason: "condition_timeout"
                )
                return .timedOut
            }
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000)
                )
            } catch {
                await recordConditionEvent(
                    result: .cancelled,
                    durationMilliseconds: elapsedMilliseconds(since: start),
                    reason: "task_cancelled"
                )
                return .cancelled
            }
        }
    }

    private func evaluateJavaScriptConditionAsync(
        _ javaScriptString: String
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javaScriptString) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(
                    returning: (result as? NSNumber)?.boolValue
                        ?? (result as? Bool)
                        ?? false
                )
            }
        }
    }

    private func recordConditionEvent(
        result: DiagnosticResult,
        durationMilliseconds: Int,
        reason: String
    ) async {
        guard let diagnosticContext = DiagnosticContext.current else { return }
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: diagnosticContext,
                component: "WKWebView",
                phase: "javascript_readiness",
                event: "condition",
                result: result,
                durationMilliseconds: durationMilliseconds,
                url: url.flatMap { DiagnosticRedactor.urlMetadata(for: $0) },
                reason: reason
            )
        )
    }

    private func elapsedMilliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1_000)
    }
}
