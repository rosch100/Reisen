import Foundation
import WebKit
import ReisenProviders

enum LoginAutofill {
    static func autofillScript(credentials: ProviderCredentials) -> String {
        LoginAutofillScript.build(username: credentials.username, password: credentials.password)
    }

    @MainActor
    static func apply(
        in webView: WKWebView,
        credentials: ProviderCredentials,
        completion: ((Bool) -> Void)? = nil
    ) {
        let script = autofillScript(credentials: credentials)
        webView.evaluateJavaScript(script) { result, _ in
            if let filled = result as? Bool {
                completion?(filled)
                return
            }
            if let dict = result as? [String: Any] {
                completion?(dict["filled"] as? Bool ?? false)
                // #region agent log
                AgentDebugLog.write(
                    hypothesisId: "X",
                    location: "LoginAutofill.swift:apply",
                    message: "fill detail",
                    data: [
                        "filled": dict["filled"] as? Bool ?? false,
                        "userFilled": dict["userFilled"] as? Int ?? 0,
                        "passFilled": dict["passFilled"] as? Int ?? 0,
                        "rememberFilled": dict["rememberFilled"] as? Int ?? 0,
                        "submitClicked": dict["submitClicked"] as? Bool ?? false,
                        "submitId": dict["submitId"] as? String ?? "",
                        "roots": dict["roots"] as? Int ?? 0,
                        "inputCountAll": dict["inputCountAll"] as? Int ?? 0,
                        "inputCountVisible": dict["inputCountVisible"] as? Int ?? 0,
                        "usernameCandidatesAll": dict["usernameCandidatesAll"] as? Int ?? 0,
                        "usernameCandidatesVisible": dict["usernameCandidatesVisible"] as? Int ?? 0,
                        "passwordCandidatesAll": dict["passwordCandidatesAll"] as? Int ?? 0,
                        "passwordCandidatesVisible": dict["passwordCandidatesVisible"] as? Int ?? 0,
                        "rememberCandidatesAll": dict["rememberCandidatesAll"] as? Int ?? 0,
                        "rememberCandidatesVisible": dict["rememberCandidatesVisible"] as? Int ?? 0,
                        "iframes": dict["iframes"] as? Int ?? 0,
                        "inputCountIframesAll": dict["inputCountIframesAll"] as? Int ?? 0,
                        "shadowRoots": dict["shadowRoots"] as? Int ?? 0,
                        "inputsDebug": dict["inputsDebug"] as? [[String: Any]] ?? [],
                    ]
                )
                // #endregion
                return
            }
            if let dict = result as? NSDictionary {
                completion?(dict["filled"] as? Bool ?? false)
                // #region agent log
                AgentDebugLog.write(
                    hypothesisId: "X",
                    location: "LoginAutofill.swift:apply",
                    message: "fill detail",
                    data: [
                        "filled": dict["filled"] as? Bool ?? false,
                        "userFilled": dict["userFilled"] as? Int ?? 0,
                        "passFilled": dict["passFilled"] as? Int ?? 0,
                        "rememberFilled": dict["rememberFilled"] as? Int ?? 0,
                        "submitClicked": dict["submitClicked"] as? Bool ?? false,
                        "submitId": dict["submitId"] as? String ?? "",
                        "roots": dict["roots"] as? Int ?? 0,
                        "inputCountAll": dict["inputCountAll"] as? Int ?? 0,
                        "inputCountVisible": dict["inputCountVisible"] as? Int ?? 0,
                        "usernameCandidatesAll": dict["usernameCandidatesAll"] as? Int ?? 0,
                        "usernameCandidatesVisible": dict["usernameCandidatesVisible"] as? Int ?? 0,
                        "passwordCandidatesAll": dict["passwordCandidatesAll"] as? Int ?? 0,
                        "passwordCandidatesVisible": dict["passwordCandidatesVisible"] as? Int ?? 0,
                        "rememberCandidatesAll": dict["rememberCandidatesAll"] as? Int ?? 0,
                        "rememberCandidatesVisible": dict["rememberCandidatesVisible"] as? Int ?? 0,
                        "iframes": dict["iframes"] as? Int ?? 0,
                        "inputCountIframesAll": dict["inputCountIframesAll"] as? Int ?? 0,
                        "shadowRoots": dict["shadowRoots"] as? Int ?? 0,
                        "inputsDebug": dict["inputsDebug"] as? [[String: Any]] ?? [],
                    ]
                )
                // #endregion
                return
            }
            completion?(false)
        }
    }
}
