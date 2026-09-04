import Foundation
import WebKit
import ReisenDiagnostics

public struct LoginAutofillResult: Sendable, Equatable {
    public let filled: Bool
    public let submitID: String?

    public init(filled: Bool, submitID: String?) {
        self.filled = filled
        self.submitID = submitID
    }
}

/// Keychain-gestütztes Ausfüllen in Provider-WKWebViews (Mac + iOS).
public enum LoginAutofill {
    @MainActor
    public static func apply(
        in webView: WKWebView,
        credentials: ProviderCredentials,
        completion: ((LoginAutofillResult) -> Void)? = nil
    ) {
        let script = LoginAutofillScript.build()
        let arguments: [String: Any] = [
            "username": credentials.username,
            "password": credentials.password,
        ]
        Task { @MainActor in
            do {
                let value = try await webView.callAsyncJavaScript(
                    script,
                    arguments: arguments,
                    contentWorld: .page
                )
                let dictionary = value as? [String: Any]
                let submitID = dictionary?["submitId"] as? String
                    ?? (value as? NSDictionary)?["submitId"] as? String
                completion?(
                    LoginAutofillResult(
                        filled: WebKitJSResult.bool(from: value, key: "filled") ?? false,
                        submitID: submitID
                    )
                )
            } catch {
                let event = DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "login_autofill"
                    ),
                    component: "LoginAutofill",
                    phase: "apply",
                    event: "login_autofill_failed",
                    result: .failed,
                    reason: String(describing: type(of: error))
                )
                Task { await DiagnosticLogger.shared.record(event) }
                completion?(LoginAutofillResult(filled: false, submitID: nil))
            }
        }
    }
}
