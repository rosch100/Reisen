import Foundation
import WebKit

/// Orchestriert Anmeldemethoden-Klick und Credential-Fill mit Retries (SPA-tauglich).
public enum ProviderLoginAssistance {
    /// E-Mail/Mobile-Methode wählen, Field-Hints und Form-Capture auf Provider-Login-Seiten.
    @MainActor
    public static func installOnLoginPage(in webView: WKWebView) {
        guard let absolute = webView.url?.absoluteString,
              AuthPageURLHeuristic.shouldApplyPasswordAutofill(absolute)
        else { return }
        webView.evaluateJavaScript(LoginMethodClickScript.build()) { _, _ in
            webView.evaluateJavaScript(LoginFieldHintsScript.build()) { _, _ in }
        }
        LoginFormCapture.install(in: webView)
    }

    /// Kein `LoginFieldHints` unmittelbar vor Fill — brach Opodo PasswordLogin.
    @MainActor
    public static func applyCredentials(
        in webView: WKWebView,
        credentials: ProviderCredentials,
        maxAttempts: Int = 3,
        retryDelays: [TimeInterval] = [0.25, 0.75],
        completion: ((Bool) -> Void)? = nil
    ) {
        var attempt = 0

        func runAttempt() {
            attempt += 1
            clickLoginMethodIfNeeded(in: webView) { _ in
                LoginAutofill.apply(in: webView, credentials: credentials) { filled in
                    if filled {
                        completion?(true)
                        return
                    }
                    guard attempt < maxAttempts else {
                        completion?(false)
                        return
                    }
                    let delay = retryDelays[min(attempt - 1, retryDelays.count - 1)]
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        runAttempt()
                    }
                }
            }
        }

        runAttempt()
    }

    @MainActor
    private static func clickLoginMethodIfNeeded(
        in webView: WKWebView,
        completion: @escaping (Bool) -> Void
    ) {
        guard let absolute = webView.url?.absoluteString,
              AuthPageURLHeuristic.shouldApplyPasswordAutofill(absolute)
        else {
            completion(false)
            return
        }
        webView.evaluateJavaScript(LoginMethodClickScript.build()) { result, _ in
            completion(WebKitJSResult.bool(from: result, key: "clicked") ?? false)
        }
    }
}
