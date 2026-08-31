import Foundation
import WebKit

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
    public static func autofillScript(credentials: ProviderCredentials) -> String {
        LoginAutofillScript.build(username: credentials.username, password: credentials.password)
    }

    @MainActor
    public static func apply(
        in webView: WKWebView,
        credentials: ProviderCredentials,
        completion: ((LoginAutofillResult) -> Void)? = nil
    ) {
        let script = autofillScript(credentials: credentials)
        webView.evaluateJavaScript(script) { result, _ in
            let dictionary = result as? [String: Any]
            let submitID = dictionary?["submitId"] as? String
                ?? (result as? NSDictionary)?["submitId"] as? String
            completion?(
                LoginAutofillResult(
                    filled: WebKitJSResult.bool(from: result, key: "filled") ?? false,
                    submitID: submitID
                )
            )
        }
    }
}
