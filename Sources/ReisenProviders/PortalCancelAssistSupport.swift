import Foundation
import WebKit
import ReisenDiagnostics
import ReisenDomain

/// Shared timing + diagnostics for portal cancel-sheet assists (BM, Opodo, Expedia Car).
public enum PortalCancelAssistSupport {
    public static let phase = "assist"
    public static let operation = "portal_cancel_assist"
    public static let eventName = "portal_cancel_assist"
    public static let pollIntervalNanoseconds: UInt64 = 400_000_000
    public static let pollTimeoutNanoseconds: UInt64 = 8_000_000_000

    public static func record(
        providerID: ProviderID,
        component: String,
        result: DiagnosticResult,
        reason: String
    ) {
        let event = DiagnosticEvent(
            context: DiagnosticContext(
                runID: UUID(),
                providerID: providerID,
                operation: operation
            ),
            component: component,
            phase: phase,
            event: eventName,
            result: result,
            reason: reason
        )
        Task {
            await DiagnosticLogger.shared.record(event)
        }
    }
}

/// One-shot task gate: at most one assist run per sheet load until `reset()`.
@MainActor
public final class PortalCancelAssistOneShot {
    private var attempted = false
    private var workTask: Task<Void, Never>?

    public init() {}

    public func reset() {
        workTask?.cancel()
        workTask = nil
        attempted = false
    }

    /// Returns `true` when a new assist task was started.
    @discardableResult
    public func startIfNeeded(
        shouldRun: Bool,
        operation: @escaping @MainActor () async -> Void
    ) -> Bool {
        guard shouldRun, !attempted else { return false }
        attempted = true
        workTask?.cancel()
        workTask = Task { @MainActor in
            await operation()
        }
        return true
    }
}

extension WKWebView {
    /// Assist JS eval: string result or `nil` (errors / non-string ignored).
    func evaluateJavaScriptStringResult(_ javaScript: String) async -> String? {
        await withCheckedContinuation { continuation in
            evaluateJavaScript(javaScript) { raw, _ in
                continuation.resume(returning: raw as? String)
            }
        }
    }
}
