import Foundation
import WebKit
import ReisenAppCore

struct LoginAssistanceTracker {
    private var lastURL: URL?

    init() {}

    mutating func shouldSchedule(for url: URL) -> Bool {
        guard lastURL != url else { return false }
        lastURL = url
        return true
    }

    mutating func reset() {
        lastURL = nil
    }
}

private final class LoginAssistanceTrackerBox {
    private var tracker = LoginAssistanceTracker()

    func shouldSchedule(for url: URL?) -> Bool {
        guard let url else { return false }
        return tracker.shouldSchedule(for: url)
    }
}

@MainActor
public final class ProviderLoginAssistanceCancellation {
    private(set) var isCancelled = false
    private var didRecordCancellation = false
    private weak var webView: WKWebView?
    private let diagnosticContext: DiagnosticContext?

    fileprivate init(webView: WKWebView, diagnosticContext: DiagnosticContext?) {
        self.webView = webView
        self.diagnosticContext = diagnosticContext
    }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        guard !didRecordCancellation, let diagnosticContext else { return }
        didRecordCancellation = true
        let event = DiagnosticEvent(
            context: diagnosticContext,
            component: "ProviderLoginAssistance",
            phase: "autofill",
            event: "cancelled",
            result: .cancelled,
            url: webView?.url.flatMap { DiagnosticRedactor.urlMetadata(for: $0) },
            reason: "task_cancelled"
        )
        Task { await DiagnosticLogger.shared.record(event) }
    }
}

public enum ProviderLoginAttemptPolicy {
    public static let maximumAllowedAttempts = 3

    public static func maximumAttempts(requested: Int) -> Int {
        max(1, min(requested, maximumAllowedAttempts))
    }

    public static func retryDelay(
        after attempt: Int,
        delays: [TimeInterval]
    ) -> TimeInterval? {
        guard attempt > 0, !delays.isEmpty, attempt <= maximumAllowedAttempts else {
            return nil
        }
        return delays[min(attempt - 1, delays.count - 1)]
    }
}

/// Orchestriert Anmeldemethoden-Klick und Credential-Fill mit Retries (SPA-tauglich).
public enum ProviderLoginAssistance {
    @MainActor
    private static let loginAssistanceTrackers = NSMapTable<WKWebView, LoginAssistanceTrackerBox>.weakToStrongObjects()

    @MainActor
    public static func shouldScheduleAssistance(in webView: WKWebView) -> Bool {
        let tracker = loginAssistanceTrackers.object(forKey: webView) ?? {
            let tracker = LoginAssistanceTrackerBox()
            loginAssistanceTrackers.setObject(tracker, forKey: webView)
            return tracker
        }()
        return tracker.shouldSchedule(for: webView.url)
    }

    @MainActor
    public static func resetAssistanceScheduling(for webView: WKWebView) {
        loginAssistanceTrackers.removeObject(forKey: webView)
    }

    /// E-Mail/Mobile-Methode wählen, Field-Hints und Form-Capture auf Provider-Login-Seiten.
    @MainActor
    public static func installOnLoginPage(
        in webView: WKWebView,
        diagnosticContext: DiagnosticContext? = nil
    ) {
        guard let absolute = webView.url?.absoluteString,
              AuthPageURLHeuristic.shouldApplyPasswordAutofill(absolute)
        else { return }
        webView.evaluateJavaScript(LoginMethodClickScript.build()) { _, error in
            recordJavaScriptError(
                error,
                context: diagnosticContext,
                phase: "login_page_setup",
                event: "login_method_script",
                url: urlMetadata(for: webView)
            )
            webView.evaluateJavaScript(LoginFieldHintsScript.build()) { _, error in
                recordJavaScriptError(
                    error,
                    context: diagnosticContext,
                    phase: "login_page_setup",
                    event: "field_hints_script",
                    url: urlMetadata(for: webView)
                )
            }
        }
        LoginFormCapture.install(in: webView)
    }

    /// Kein `LoginFieldHints` unmittelbar vor Fill — brach Opodo PasswordLogin.
    @MainActor
    @discardableResult
    public static func applyCredentials(
        in webView: WKWebView,
        credentials: ProviderCredentials,
        maxAttempts: Int = 3,
        retryDelays: [TimeInterval] = [0.25, 0.75],
        diagnosticContext: DiagnosticContext? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> ProviderLoginAssistanceCancellation {
        let cancellation = ProviderLoginAssistanceCancellation(
            webView: webView,
            diagnosticContext: diagnosticContext
        )
        let maximumAttempts = ProviderLoginAttemptPolicy.maximumAttempts(requested: maxAttempts)
        var attempt = 0

        func runAttempt() {
            guard !cancellation.isCancelled else { return }
            attempt += 1
            if let diagnosticContext {
                Task {
                    await DiagnosticLogger.shared.record(
                        DiagnosticEvent(
                            context: diagnosticContext,
                            component: "ProviderLoginAssistance",
                            phase: "autofill",
                            event: "attempt",
                            result: .started,
                            attempt: attempt,
                            url: urlMetadata(for: webView)
                        )
                    )
                }
            }
            clickLoginMethodIfNeeded(in: webView, diagnosticContext: diagnosticContext) { _ in
                guard !cancellation.isCancelled else { return }
                LoginAutofill.apply(in: webView, credentials: credentials) { filled in
                    guard !cancellation.isCancelled else { return }
                    if filled.filled {
                        if let diagnosticContext {
                            Task {
                                await DiagnosticLogger.shared.record(
                                    DiagnosticEvent(
                                        context: diagnosticContext,
                                        component: "ProviderLoginAssistance",
                                        phase: "autofill",
                                        event: "filled",
                                        result: .succeeded,
                                        attempt: attempt,
                                        url: urlMetadata(for: webView),
                                        reason: filled.submitID.map {
                                            "submit_id=\(DiagnosticRedactor.redact($0))"
                                        }
                                    )
                                )
                            }
                        }
                        completion?(true)
                        return
                    }
                    guard attempt < maximumAttempts,
                          let delay = ProviderLoginAttemptPolicy.retryDelay(
                              after: attempt,
                              delays: retryDelays
                          )
                    else {
                        if let diagnosticContext {
                            Task {
                                await DiagnosticLogger.shared.record(
                                    DiagnosticEvent(
                                        context: diagnosticContext,
                                        component: "ProviderLoginAssistance",
                                        phase: "autofill",
                                        event: "retries_exhausted",
                                        result: .failed,
                                        attempt: attempt,
                                        url: urlMetadata(for: webView),
                                        reason: retryDelays.isEmpty
                                            ? "retry_schedule_missing"
                                            : "fill_failed"
                                    )
                                )
                            }
                        }
                        completion?(false)
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        guard !cancellation.isCancelled else { return }
                        runAttempt()
                    }
                }
            }
        }

        runAttempt()
        return cancellation
    }

    @MainActor
    private static func clickLoginMethodIfNeeded(
        in webView: WKWebView,
        diagnosticContext: DiagnosticContext?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let absolute = webView.url?.absoluteString,
              AuthPageURLHeuristic.shouldApplyPasswordAutofill(absolute)
        else {
            completion(false)
            return
        }
        webView.evaluateJavaScript(LoginMethodClickScript.build()) { result, error in
            recordJavaScriptError(
                error,
                context: diagnosticContext,
                phase: "autofill",
                event: "login_method_click",
                url: urlMetadata(for: webView)
            )
            completion(WebKitJSResult.bool(from: result, key: "clicked") ?? false)
        }
    }

    private static func recordJavaScriptError(
        _ error: Error?,
        context: DiagnosticContext?,
        phase: String,
        event: String,
        url: String?
    ) {
        guard let error, let context else { return }
        let diagnosticEvent = DiagnosticEvent(
            context: context,
            component: "ProviderLoginAssistance",
            phase: phase,
            event: event,
            result: .failed,
            url: url,
            errorType: String(describing: type(of: error)),
            reason: DiagnosticRedactor.redact(error.localizedDescription)
        )
        Task { await DiagnosticLogger.shared.record(diagnosticEvent) }
    }

    @MainActor
    private static func urlMetadata(for webView: WKWebView) -> String? {
        webView.url.flatMap(DiagnosticRedactor.urlMetadata(for:))
    }
}
