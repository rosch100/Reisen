import Foundation
import ReisenDiagnostics

@MainActor
public enum NavigationSettleLoop {
    public static func wait(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        deadline: Date,
        timeoutURL: URL,
        diagnosticContext: DiagnosticContext? = nil
    ) async throws {
        var sawLoading = webView.isLoading
        var previousURL = webView.url
        var previousLoading = webView.isLoading
        var previousTargetMatch = NavigationTargetMatching.isOnTarget(
            webView: webView,
            host: targetHost,
            path: targetPath
        )

        while Date() < deadline {
            let currentURL = webView.url
            let currentLoading = webView.isLoading
            let currentTargetMatch = NavigationTargetMatching.isOnTarget(
                webView: webView,
                host: targetHost,
                path: targetPath
            )
            if let diagnosticContext {
                if currentURL != previousURL {
                    await record(
                        context: diagnosticContext,
                        event: "url_changed",
                        result: .started,
                        url: currentURL
                    )
                }
                if currentLoading != previousLoading {
                    await record(
                        context: diagnosticContext,
                        event: "loading_changed",
                        result: .started,
                        url: currentURL,
                        reason: "is_loading=\(currentLoading)"
                    )
                }
                if currentTargetMatch != previousTargetMatch {
                    await record(
                        context: diagnosticContext,
                        event: "target_match_changed",
                        result: currentTargetMatch ? .succeeded : .started,
                        url: currentURL,
                        reason: "target_match=\(currentTargetMatch)"
                    )
                }
                await record(
                    context: diagnosticContext,
                    event: "poll",
                    result: .started,
                    url: webView.url,
                    reason: "is_loading=\(webView.isLoading),saw_loading=\(sawLoading),target=\(NavigationTargetMatching.isOnTarget(webView: webView, host: targetHost, path: targetPath))"
                )
            }
            if try await NavigationSettlePoll.tick(
                webView: webView,
                targetHost: targetHost,
                targetPath: targetPath,
                sawLoading: &sawLoading,
                diagnosticContext: diagnosticContext
            ) {
                return
            }
            previousURL = currentURL
            previousLoading = currentLoading
            previousTargetMatch = currentTargetMatch
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NavigationSettleTimeout.error(for: timeoutURL)
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
