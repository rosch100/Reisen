import Foundation
import WebKit

/// Marks OTP inputs so macOS/iOS Security Code AutoFill can suggest SMS/Mail codes.
public enum OneTimeCodeAutofill {
    public static func script(relaxSplitFieldMaxLength: Bool = false) -> String {
        OneTimeCodeAutofillScript.build(relaxSplitFieldMaxLength: relaxSplitFieldMaxLength)
    }

    @MainActor
    public static func apply(in webView: WKWebView, relaxSplitFieldMaxLength: Bool = false) {
        webView.evaluateJavaScript(script(relaxSplitFieldMaxLength: relaxSplitFieldMaxLength)) { _, _ in }
    }
}
