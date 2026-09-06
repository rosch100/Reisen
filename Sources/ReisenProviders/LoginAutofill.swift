import Foundation
import WebKit
import ReisenDiagnostics

public struct LoginAutofillResult: Sendable, Equatable {
    /// JS-`filled`: mindestens ein Feld gesetzt (E-Mail, Passwort oder Remember).
    public let anyFieldFilled: Bool
    public let submitID: String?
    public let userFilled: Int
    public let passFilled: Int

    public init(
        anyFieldFilled: Bool,
        submitID: String?,
        userFilled: Int = 0,
        passFilled: Int = 0
    ) {
        self.anyFieldFilled = anyFieldFilled
        self.submitID = submitID
        self.userFilled = userFilled
        self.passFilled = passFilled
    }

    public var fillCountsReason: String {
        "user_filled=\(userFilled) pass_filled=\(passFilled)"
    }

    var diagnosticReason: String {
        let submit = submitID.map { "submit_id=\(DiagnosticRedactor.redact($0))" }
        return [fillCountsReason, submit].compactMap { $0 }.joined(separator: " ")
    }

    public func isComplete(passwordExpected: Bool) -> Bool {
        if passwordExpected {
            return passFilled > 0
        }
        return anyFieldFilled
    }

    public static func parse(from value: Any?) -> LoginAutofillResult {
        let dictionary = value as? [String: Any]
        let nsDictionary = value as? NSDictionary
        let submitID = dictionary?["submitId"] as? String
            ?? nsDictionary?["submitId"] as? String
        return LoginAutofillResult(
            anyFieldFilled: WebKitJSResult.bool(from: value, key: "filled") ?? false,
            submitID: submitID,
            userFilled: WebKitJSResult.int(from: value, key: "userFilled") ?? 0,
            passFilled: WebKitJSResult.int(from: value, key: "passFilled") ?? 0
        )
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
                completion?(LoginAutofillResult.parse(from: value))
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
                completion?(LoginAutofillResult(anyFieldFilled: false, submitID: nil))
            }
        }
    }
}
