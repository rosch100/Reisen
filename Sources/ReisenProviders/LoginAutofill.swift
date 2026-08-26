import Foundation
import WebKit

/// Keychain-gestütztes Ausfüllen in Provider-WKWebViews (Mac + iOS).
public enum LoginAutofill {
    public static func autofillScript(credentials: ProviderCredentials) -> String {
        LoginAutofillScript.build(username: credentials.username, password: credentials.password)
    }

    @MainActor
    public static func apply(
        in webView: WKWebView,
        credentials: ProviderCredentials,
        completion: ((Bool) -> Void)? = nil
    ) {
        let script = autofillScript(credentials: credentials)
        webView.evaluateJavaScript(script) { result, _ in
            completion?(WebKitJSResult.bool(from: result, key: "filled") ?? false)
        }
    }
}
