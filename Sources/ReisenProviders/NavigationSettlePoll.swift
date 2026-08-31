import Foundation
import ReisenDiagnostics

@MainActor
public enum NavigationSettlePoll {
    public static func tick(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: inout Bool,
        diagnosticContext: DiagnosticContext? = nil
    ) async throws -> Bool {
        if webView.isLoading { sawLoading = true }
        let confirmed = try await NavigationSettleConfirm.tryConfirm(
            webView: webView,
            targetHost: targetHost,
            targetPath: targetPath,
            sawLoading: sawLoading
        )
        if let diagnosticContext {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: diagnosticContext,
                    component: "NavigationSettlePoll",
                    phase: "navigation",
                    event: "settle_check",
                    result: confirmed ? .succeeded : .started,
                    url: webView.url?.absoluteString,
                    reason: "confirmed=\(confirmed)"
                )
            )
        }
        return confirmed
    }
}
