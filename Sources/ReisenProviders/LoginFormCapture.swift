import Foundation
import WebKit

public enum LoginFormCapture {
    public static let messageHandlerName = LoginFormCaptureScript.messageHandlerName

    @MainActor
    public static func install(in webView: WKWebView) {
        webView.evaluateJavaScript(LoginFormCaptureScript.build()) { _, _ in }
    }

    /// Nur Main-Frame und Provider-Login-URLs auf erlaubten Hosts (keine IdP-/iframe-Injection).
    @MainActor
    public static func accepts(
        message: WKScriptMessage,
        webView: WKWebView?,
        allowedServerHosts: [String]
    ) -> Bool {
        guard message.frameInfo.isMainFrame else { return false }
        guard let absolute = webView?.url?.absoluteString, !absolute.isEmpty else { return false }
        return AuthPageURLHeuristic.shouldApplyPasswordAutofill(
            absolute,
            allowedServerHosts: allowedServerHosts
        )
    }

    public static func parseCredentials(from body: Any) -> ProviderCredentials? {
        guard let dict = body as? [String: Any],
              dict["type"] as? String == "credentials",
              let username = dict["username"] as? String,
              let password = dict["password"] as? String,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty
        else {
            return nil
        }
        return ProviderCredentials(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }

    @MainActor
    public static func handleScriptMessage(
        _ message: WKScriptMessage,
        webView: WKWebView?,
        allowedServerHosts: [String],
        onCredentials: (ProviderCredentials) -> Void
    ) {
        guard message.name == messageHandlerName else { return }
        guard accepts(message: message, webView: webView, allowedServerHosts: allowedServerHosts) else { return }
        guard let credentials = parseCredentials(from: message.body) else { return }
        onCredentials(credentials)
    }
}
