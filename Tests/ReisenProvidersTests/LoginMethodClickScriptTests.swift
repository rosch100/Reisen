import Testing
import ReisenProviders

@Test
func loginMethodClickScriptDetectsEmailOrMobileAndAvoidsSocial() {
    let script = LoginMethodClickScript.build()

    #expect(script.contains("email\\s*or\\s*mobile"))
    #expect(script.contains("e-?mail\\s*oder\\s*mobil"))
    #expect(script.contains("isSocialOrIdP"))
    #expect(script.contains("sign.?in.?with"))
    #expect(script.contains("apple"))
    #expect(script.contains("clicked"))
    #expect(script.contains("reisenLoginMethodSetup"))
}

@Test
func loginFieldHintsScriptRecognizesTelAndMobileFields() {
    let script = LoginFieldHintsScript.build()

    #expect(script.contains("type === 'tel'"))
    #expect(script.contains("inputmode"))
    #expect(script.contains("mobile"))
    #expect(script.contains("telefon"))
}

@Test
func loginAutofillScriptRecognizesTelAndMobileFields() {
    let script = LoginAutofillScript.build()

    #expect(script.contains("type === 'tel'"))
    #expect(script.contains("inputmode"))
    #expect(script.contains("mobile"))
    #expect(script.contains("handy"))
}
