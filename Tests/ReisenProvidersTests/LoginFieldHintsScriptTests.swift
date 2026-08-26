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
