import Foundation
import ReisenDiagnostics

@MainActor
public enum NavigationSettleLoop {
    private static let pollIntervalNanoseconds: UInt64 = 100_000_000

    public static func wait(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        deadline: Date,
        timeoutURL: URL,
        diagnosticContext: DiagnosticContext? = nil
    ) async throws {
        var sawLoading = webView.isLoading
        var previous = TickState(webView: webView, host: targetHost, path: targetPath)
        var onTargetSince: Date? = previous.isOnTarget ? Date() : nil

        while Date() < deadline {
            let current = TickState(webView: webView, host: targetHost, path: targetPath)
            onTargetSince = current.isOnTarget ? (onTargetSince ?? Date()) : nil
            await recordTransitions(from: previous, to: current, context: diagnosticContext)
            if try await NavigationSettlePoll.tick(
                webView: webView,
                targetHost: targetHost,
                targetPath: targetPath,
                sawLoading: &sawLoading,
                onTargetSince: onTargetSince
            ) {
                return
            }
            previous = current
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        if TickState(webView: webView, host: targetHost, path: targetPath).isOnTarget {
            if let diagnosticContext {
                await record(
                    context: diagnosticContext,
                    event: "deadline_on_target",
                    result: .succeeded,
                    url: webView.url,
                    reason: "on_target_at_deadline"
                )
            }
            return
        }
        throw NavigationSettleTimeout.error(for: timeoutURL)
    }

    private struct TickState {
        var url: URL?
        var isLoading: Bool
        var isOnTarget: Bool

        @MainActor
        init(webView: NavigationWebView, host: String, path: String) {
            url = webView.url
            isLoading = webView.isLoading
            isOnTarget = NavigationTargetMatching.isOnTarget(
                webView: webView,
                host: host,
                path: path
            )
        }
    }

    private static func recordTransitions(
        from previous: TickState,
        to current: TickState,
        context: DiagnosticContext?
    ) async {
        guard let context else { return }
        if current.url != previous.url {
            await record(
                context: context,
                event: "url_changed",
                result: .started,
                url: current.url
            )
        }
        if current.isLoading != previous.isLoading {
            await record(
                context: context,
                event: "loading_changed",
                result: .started,
                url: current.url,
                reason: "is_loading=\(current.isLoading)"
            )
        }
        if current.isOnTarget != previous.isOnTarget {
            await record(
                context: context,
                event: "target_match_changed",
                result: current.isOnTarget ? .succeeded : .started,
                url: current.url,
                reason: "target_match=\(current.isOnTarget)"
            )
        }
    }

    /// URL roh; Host-Redaction ist SSOT in `DiagnosticLogger`.
    private static func record(
        context: DiagnosticContext,
        event: String,
        result: DiagnosticResult,
        url: URL?,
        reason: String? = nil
    ) async {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "NavigationSettleLoop",
                phase: "navigation",
                event: event,
                result: result,
                url: url?.absoluteString,
                reason: reason
            )
        )
    }
}
