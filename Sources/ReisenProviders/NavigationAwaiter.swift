import Foundation
import WebKit
import ReisenDiagnostics

/// Wartet auf Navigation-Abschluss, **ohne** den bestehenden `navigationDelegate` zu stehlen.
/// SwiftUI/`ProviderSessionView` setzt den Delegate sonst zurück → Timeout (NavigationAwaiter-Fehler 1),
/// obwohl die Seite bereits geladen ist.
@MainActor
public final class NavigationAwaiter: NSObject {
    private let timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 25) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func load(
        _ url: URL,
        in webView: NavigationWebView,
        diagnosticContext: DiagnosticContext? = nil
    ) async throws {
        let context = diagnosticContext ?? DiagnosticContext.current
        let targetHost = (url.host ?? "").lowercased()
        let targetPath = NavigationTargetMatching.normalizedPath(url.path)
        let start = Date()
        if let context {
            await record(
                context: context,
                event: "started",
                result: .started,
                url: url
            )
        }

        if NavigationTargetMatching.isOnTarget(webView: webView, host: targetHost, path: targetPath),
           !webView.isLoading {
            if let context {
                await record(
                    context: context,
                    event: "already_on_target",
                    result: .skipped,
                    url: webView.url
                )
            }
            return
        }

        _ = webView.load(URLRequest(url: url))

        do {
            try await NavigationSettleLoop.wait(
                webView: webView,
                targetHost: targetHost,
                targetPath: targetPath,
                deadline: Date().addingTimeInterval(timeoutSeconds),
                timeoutURL: url,
                diagnosticContext: context
            )
            if let context {
                await record(
                    context: context,
                    event: "completed",
                    result: .succeeded,
                    durationMilliseconds: elapsedMilliseconds(since: start),
                    url: webView.url
                )
            }
        } catch {
            let timedOut = NavigationSettleTimeout.isTimeout(error)
            if let context {
                await record(
                    context: context,
                    event: "failed",
                    result: Task.isCancelled ? .cancelled : (timedOut ? .timedOut : .failed),
                    durationMilliseconds: elapsedMilliseconds(since: start),
                    url: webView.url ?? url,
                    errorType: String(reflecting: type(of: error)),
                    reason: Task.isCancelled
                        ? "task_cancelled"
                        : (timedOut ? NavigationSettleTimeout.diagnosticReason : DiagnosticRedactor.redact(error.localizedDescription))
                )
            }
            throw error
        }
    }

    private func record(
        context: DiagnosticContext,
        event: String,
        result: DiagnosticResult,
        durationMilliseconds: Int? = nil,
        url: URL?,
        errorType: String? = nil,
        reason: String? = nil
    ) async {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "NavigationAwaiter",
                phase: "navigation",
                event: event,
                result: result,
                durationMilliseconds: durationMilliseconds,
                url: url?.absoluteString,
                errorType: errorType,
                reason: reason
            )
        )
    }

    private func elapsedMilliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1_000)
    }
}
