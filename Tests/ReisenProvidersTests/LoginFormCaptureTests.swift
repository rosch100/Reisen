import Testing
@testable import ReisenProviders

@Test
func loginFormCaptureScriptRegistersSubmitHandler() {
    let script = LoginFormCaptureScript.build()

    #expect(script.contains("reisenLoginCapture"))
    #expect(script.contains("credentials"))
    #expect(script.contains("addEventListener('submit'"))
    #expect(script.contains("looksLikeUsername"))
    #expect(script.contains("looksLikePassword"))
}

@Test
func loginFormCaptureParsesValidPayload() {
    let body: [String: Any] = [
        "type": "credentials",
        "username": "user@example.com",
        "password": "secret",
    ]
    let credentials = LoginFormCapture.parseCredentials(from: body)
    #expect(credentials?.username == "user@example.com")
    #expect(credentials?.password == "secret")
}

@Test
func loginFormCaptureRejectsIncompletePayload() {
    let body: [String: Any] = [
        "type": "credentials",
        "username": "user@example.com",
        "password": "",
    ]
    #expect(LoginFormCapture.parseCredentials(from: body) == nil)
}
