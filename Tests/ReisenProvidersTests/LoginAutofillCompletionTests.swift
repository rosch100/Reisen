import Foundation
import Testing
import ReisenProviders

@Test
func loginAutofillEmailOnlyIsIncompleteWhenPasswordExpected() {
    let emailOnly = LoginAutofillResult.parse(
        from: [
            "filled": true,
            "userFilled": 1,
            "passFilled": 0,
            "submitId": "continue",
        ] as [String: Any]
    )

    #expect(emailOnly.userFilled == 1)
    #expect(emailOnly.passFilled == 0)
    #expect(emailOnly.anyFieldFilled)
    #expect(emailOnly.submitID == "continue")
    #expect(emailOnly.isComplete(passwordExpected: true) == false)
    #expect(emailOnly.isComplete(passwordExpected: false) == true)
}

@Test
func loginAutofillPasswordStepIsCompleteWhenPasswordExpected() {
    let both = LoginAutofillResult.parse(
        from: [
            "filled": true,
            "userFilled": 1,
            "passFilled": 1,
        ] as [String: Any]
    )

    #expect(both.isComplete(passwordExpected: true) == true)
    #expect(both.fillCountsReason == "user_filled=1 pass_filled=1")
}

@Test
func travelokaEmailStepHTMLRequiresContinueThenPassword() throws {
    let emailHTML = try travelokaAutofillFixture("traveloka_email_step.html")
    let passwordHTML = try travelokaAutofillFixture("traveloka_password_step.html")

    #expect(emailHTML.contains("id=\"auth-username\""))
    #expect(emailHTML.contains(">Continue<"))
    #expect(!emailHTML.contains("type=\"password\""))
    #expect(passwordHTML.contains("type=\"password\""))
    #expect(passwordHTML.contains("id=\"auth-password\""))

    #expect(LoginAutofillFieldHeuristic.looksLikeUsernameStepSubmit(hay: "Continue"))
    #expect(LoginAutofillFieldHeuristic.looksLikeUsernameStepSubmit(hay: "Weiter"))
    #expect(!LoginAutofillFieldHeuristic.looksLikeUsernameStepSubmit(hay: "Continue with Apple"))
    #expect(
        LoginAutofillFieldHeuristic.looksLikePassword(
            type: "password",
            hay: "auth-password current-password"
        )
    )
    #expect(
        !LoginAutofillFieldHeuristic.looksLikePassword(
            type: "text",
            hay: "auth-username email"
        )
    )

    let script = LoginAutofillScript.build()
    #expect(script.contains(LoginAutofillFieldHeuristic.submitHayPattern))
    #expect(script.contains(LoginAutofillFieldHeuristic.usernameStepSubmitPattern))
}

private func travelokaAutofillFixture(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}
