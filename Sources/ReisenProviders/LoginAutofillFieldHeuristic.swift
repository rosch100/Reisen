import Foundation

/// SSOT für Login-Feld- und Submit-Erkennung (Swift-Tests + JS-Script).
public enum LoginAutofillFieldHeuristic {
    public static let submitHayPattern =
        "c24-uli-pw-btn|c24-uli-login-btn|submit-button|anmelden|einloggen|log.?in|sign.?in|continue|weiter"
    public static let usernameStepSubmitPattern = "continue|weiter"
    public static let socialSubmitPattern =
        "sign.?in.?with.?(apple|google|facebook)|continue.?with.?(apple|google|facebook)|login.?with.?(apple|google|facebook)|anmelden.?mit.?(apple|google|facebook)|passkey"
    public static let passwordHayPattern =
        "current-password|password|passwort|kennwort|passwd|pwd|pass|cl_pw_login|uli-input-pw"

    public static func looksLikePassword(type: String, hay: String) -> Bool {
        if type.lowercased() == "password" { return true }
        return hay.range(of: passwordHayPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    public static func looksLikeUsernameStepSubmit(hay: String) -> Bool {
        guard hay.range(of: socialSubmitPattern, options: [.regularExpression, .caseInsensitive]) == nil else {
            return false
        }
        return hay.range(of: usernameStepSubmitPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
