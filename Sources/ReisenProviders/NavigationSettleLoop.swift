import Foundation
import ReisenAppCore

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
                    await DiagnosticLogger.shared.record(
                        DiagnosticEvent(
                            context: diagnosticContext,
                            component: "NavigationSettleLoop",
                            phase: "navigation",
                            event: "url_changed",
                            result: .started,
                            url: currentURL.flatMap { DiagnosticRedactor.urlMetadata(for: $0) }
                        )
                    )
                }
                if currentLoading != previousLoading {
                    await DiagnosticLogger.shared.record(
                        DiagnosticEvent(
                            context: diagnosticContext,
                            component: "NavigationSettleLoop",
                            phase: "navigation",
                            event: "loading_changed",
                            result: .started,
                            url: currentURL.flatMap { DiagnosticRedactor.urlMetadata(for: $0) },
                            reason: "is_loading=\(currentLoading)"
                        )
                    )
                }
                if currentTargetMatch != previousTargetMatch {
                    await DiagnosticLogger.shared.record(
                        DiagnosticEvent(
                            context: diagnosticContext,
                            component: "NavigationSettleLoop",
                            phase: "navigation",
                            event: "target_match_changed",
                            result: currentTargetMatch ? .succeeded : .started,
                            url: currentURL.flatMap { DiagnosticRedactor.urlMetadata(for: $0) },
                            reason: "target_match=\(currentTargetMatch)"
                        )
                    )
                }
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: diagnosticContext,
                        component: "NavigationSettleLoop",
                        phase: "navigation",
                        event: "poll",
                        result: .started,
                        url: webView.url.flatMap { DiagnosticRedactor.urlMetadata(for: $0) },
                        reason: "is_loading=\(webView.isLoading),saw_loading=\(sawLoading),target=\(NavigationTargetMatching.isOnTarget(webView: webView, host: targetHost, path: targetPath))"
                    )
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
}
