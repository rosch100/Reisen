import Testing
import ReisenProviders

@Test
func loginFieldHintsScriptMarksUsernamePasswordAndShadowDOM() {
    let script = LoginFieldHintsScript.build()

    #expect(script.contains("autocomplete"))
    #expect(script.contains("username"))
    #expect(script.contains("current-password"))
    #expect(script.contains("shadowRoot"))
    #expect(script.contains("unified-login"))
    #expect(script.contains("reisenLoginFields"))
    #expect(script.contains("type === 'tel'"))
    #expect(script.contains("mobile"))
}

@Test
func loginFieldHintsScriptNotifiesNativeOnLoginInputFocusAndBlur() {
    let script = LoginFieldHintsScript.build()
    #expect(script.contains("inputFocused"))
    #expect(script.contains("inputBlurred"))
    #expect(script.contains("focusin"))
    #expect(script.contains("focusout"))
}

@Test
func loginFieldHintsMessageParsesFocusEvents() {
    #expect(LoginFieldHintsMessage.webLoginInputFocused(["type": "inputFocused"]) == true)
    #expect(LoginFieldHintsMessage.webLoginInputFocused(["type": "inputBlurred"]) == false)
    #expect(LoginFieldHintsMessage.webLoginInputFocused(["type": "fieldsChanged"]) == nil)
    #expect(LoginFieldHintsMessage.webLoginInputFocused("inputFocused") == nil)
}
