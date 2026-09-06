import Foundation
import WebKit
import ReisenDiagnostics

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
            url: webView?.url?.absoluteString,
            reason: "task_cancelled"
        )
        Task { await DiagnosticLogger.shared.record(event) }
    }
}

public enum LoginAssistanceFillNextStep: Equatable, Sendable {
    case succeeded
    case startPasswordStep(delay: TimeInterval)
    case retry(delay: TimeInterval)
    case exhausted(reason: String)
}

public enum ProviderLoginAttemptPolicy {
    public static let maximumAllowedAttempts = 3
    /// Kurze Retries bis Login-Felder überhaupt da sind.
    public static let defaultRetryDelays: [TimeInterval] = [0.25, 0.75]
    /// Nach E-Mail+Continue: SPA braucht länger bis zum Passwortfeld (Traveloka).
    public static let passwordStepRetryDelays: [TimeInterval] = [1.0, 2.0]

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

    /// Entscheidung nach einem Autofill-Versuch (SSOT für applyCredentials + Tests).
    public static func nextStep(
        passwordExpected: Bool,
        result: LoginAutofillResult,
        attempt: Int,
        maximumAttempts: Int,
        sawUsernameWithoutPassword: Bool,
        initialRetryDelays: [TimeInterval]
    ) -> LoginAssistanceFillNextStep {
        if result.isComplete(passwordExpected: passwordExpected) {
            return .succeeded
        }

        if passwordExpected,
           !sawUsernameWithoutPassword,
           result.userFilled > 0,
           result.passFilled == 0 {
            return .startPasswordStep(delay: passwordStepRetryDelays[0])
        }

        let activeDelays = sawUsernameWithoutPassword
            ? passwordStepRetryDelays
            : initialRetryDelays
        guard !activeDelays.isEmpty else {
            return .exhausted(reason: "retry_schedule_missing")
        }
        guard attempt < maximumAttempts,
              let delay = retryDelay(after: attempt, delays: activeDelays)
        else {
            return .exhausted(reason: "fill_failed \(result.fillCountsReason)")
        }
        return .retry(delay: delay)
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
        allowedServerHosts: [String],
        diagnosticContext: DiagnosticContext? = nil
    ) {
        guard let absolute = webView.url?.absoluteString,
              AuthPageURLHeuristic.shouldApplyPasswordAutofill(
                absolute,
                allowedServerHosts: allowedServerHosts
              )
        else { return }
        webView.evaluateJavaScript(LoginMethodClickScript.build()) { _, error in
            recordJavaScriptError(
                error,
                context: diagnosticContext,
                phase: "login_page_setup",
                event: "login_method_script",
                url: urlForLog(for: webView)
            )
            webView.evaluateJavaScript(LoginFieldHintsScript.build()) { _, error in
                recordJavaScriptError(
                    error,
                    context: diagnosticContext,
                    phase: "login_page_setup",
                    event: "field_hints_script",
                    url: urlForLog(for: webView)
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
        allowedServerHosts: [String],
        maxAttempts: Int = 3,
        retryDelays: [TimeInterval] = ProviderLoginAttemptPolicy.defaultRetryDelays,
        diagnosticContext: DiagnosticContext? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> ProviderLoginAssistanceCancellation {
        let cancellation = ProviderLoginAssistanceCancellation(
            webView: webView,
            diagnosticContext: diagnosticContext
        )
        let maximumAttempts = ProviderLoginAttemptPolicy.maximumAttempts(requested: maxAttempts)
        var attempt = 0
        var sawUsernameWithoutPassword = false
        let initialRetryDelays = retryDelays

        func finish(succeeded: Bool, exhaustedReason: String?) {
            if !succeeded {
                resetAssistanceScheduling(for: webView)
                if let diagnosticContext {
                    Task {
                        await DiagnosticLogger.shared.record(
                            DiagnosticEvent(
                                context: diagnosticContext,
                                component: "ProviderLoginAssistance",
                                phase: "autofill",
                                event: "scheduling_reset",
                                result: .succeeded,
                                attempt: attempt,
                                url: urlForLog(for: webView),
                                reason: exhaustedReason ?? "fill_incomplete"
                            )
                        )
                    }
                }
            }
            if let exhaustedReason, let diagnosticContext, !succeeded {
                Task {
                    await DiagnosticLogger.shared.record(
                        DiagnosticEvent(
                            context: diagnosticContext,
                            component: "ProviderLoginAssistance",
                            phase: "autofill",
                            event: "retries_exhausted",
                            result: .failed,
                            attempt: attempt,
                            url: urlForLog(for: webView),
                            reason: exhaustedReason
                        )
                    )
                }
            }
            completion?(succeeded)
        }

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
                            url: urlForLog(for: webView)
                        )
                    )
                }
            }
            clickLoginMethodIfNeeded(
                in: webView,
                allowedServerHosts: allowedServerHosts,
                diagnosticContext: diagnosticContext
            ) { _ in
                guard !cancellation.isCancelled else { return }
                LoginAutofill.apply(in: webView, credentials: credentials) { autofillResult in
                    guard !cancellation.isCancelled else { return }
                    let passwordExpected = !credentials.password.isEmpty
                    let step = ProviderLoginAttemptPolicy.nextStep(
                        passwordExpected: passwordExpected,
                        result: autofillResult,
                        attempt: attempt,
                        maximumAttempts: maximumAttempts,
                        sawUsernameWithoutPassword: sawUsernameWithoutPassword,
                        initialRetryDelays: initialRetryDelays
                    )
                    switch step {
                    case .succeeded:
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
                                        url: urlForLog(for: webView),
                                        reason: autofillResult.diagnosticReason
                                    )
                                )
                            }
                        }
                        finish(succeeded: true, exhaustedReason: nil)
                    case .startPasswordStep(let delay):
                        sawUsernameWithoutPassword = true
                        attempt = 0
                        if let diagnosticContext {
                            Task {
                                await DiagnosticLogger.shared.record(
                                    DiagnosticEvent(
                                        context: diagnosticContext,
                                        component: "ProviderLoginAssistance",
                                        phase: "autofill",
                                        event: "filled_partial",
                                        result: .started,
                                        attempt: 1,
                                        url: urlForLog(for: webView),
                                        reason: autofillResult.diagnosticReason
                                    )
                                )
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            guard !cancellation.isCancelled else { return }
                            runAttempt()
                        }
                    case .retry(let delay):
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            guard !cancellation.isCancelled else { return }
                            runAttempt()
                        }
                    case .exhausted(let reason):
                        finish(succeeded: false, exhaustedReason: reason)
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
        allowedServerHosts: [String],
        diagnosticContext: DiagnosticContext?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let absolute = webView.url?.absoluteString,
              AuthPageURLHeuristic.shouldApplyPasswordAutofill(
                absolute,
                allowedServerHosts: allowedServerHosts
              )
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
                url: urlForLog(for: webView)
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
    private static func urlForLog(for webView: WKWebView) -> String? {
        webView.url?.absoluteString
    }
}
