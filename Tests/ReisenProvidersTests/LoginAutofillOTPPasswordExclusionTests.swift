import Testing
import ReisenProviders

@Test
func loginAutofillDoesNotTreatExpediaOneTimePasscodeAsPassword() {
    // HAR expedia.de auth-ui: OTP input id contains "passcode"; label "6-stelliger Code".
    let expediaOTPHay =
        "verify-sms-one-time-passcode-input oneTimePasscodeField 6-stelliger Code"

    #expect(
        !LoginAutofillFieldHeuristic.looksLikePassword(type: "text", hay: expediaOTPHay)
    )
    #expect(
        !LoginAutofillFieldHeuristic.looksLikePassword(type: "tel", hay: expediaOTPHay)
    )
    // Even if type=password is used for masking, OTP attrs must win.
    #expect(
        !LoginAutofillFieldHeuristic.looksLikePassword(type: "password", hay: expediaOTPHay)
    )
}

@Test
func loginAutofillDoesNotTreatBarePasscodeHayAsPassword() {
    #expect(!LoginAutofillFieldHeuristic.looksLikePassword(type: "text", hay: "passcode"))
    #expect(!LoginAutofillFieldHeuristic.looksLikePassword(type: "text", hay: "one-time-passcode"))
    #expect(!LoginAutofillFieldHeuristic.looksLikePassword(type: "text", hay: "Enter passcode"))
}

@Test
func loginAutofillStillRecognizesRealPasswordFields() {
    #expect(
        LoginAutofillFieldHeuristic.looksLikePassword(
            type: "password",
            hay: "auth-password current-password"
        )
    )
    #expect(
        LoginAutofillFieldHeuristic.looksLikePassword(
            type: "text",
            hay: "cl_pw_login c24-uli-input-pw"
        )
    )
    #expect(
        LoginAutofillFieldHeuristic.looksLikePassword(type: "text", hay: "passwort kennwort")
    )
    // OTP-Exclude darf Substrings in normalen Passwort-Hays nicht matchen (`tan` in standard/instant).
    #expect(
        LoginAutofillFieldHeuristic.looksLikePassword(type: "password", hay: "standard-password")
    )
    #expect(
        LoginAutofillFieldHeuristic.looksLikePassword(type: "password", hay: "instant-login-password")
    )
}

@Test
func loginAutofillPasswordHayPatternOmitsUnanchoredPassToken() {
    // Bare `pass` matched substrings inside "passcode" (Expedia OTP id).
    let pattern = LoginAutofillFieldHeuristic.passwordHayPattern
    #expect(!pattern.split(separator: "|").contains("pass"))
}

@Test
func loginAutofillScriptExcludesOneTimePasscodeFromPasswordFill() {
    let script = LoginAutofillScript.build()
    #expect(script.contains("looksLikeOneTimeCode"))
    #expect(script.contains("if (looksLikeOneTimeCode(el)) return false"))
}
