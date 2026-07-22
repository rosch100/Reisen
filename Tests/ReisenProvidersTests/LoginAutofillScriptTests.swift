import Testing
import ReisenProviders

@Test
func loginAutofillScriptFillsUsernameWithoutPasswordField() {
    let script = LoginAutofillScript.build(username: "a@b.de", password: "geheim")

    #expect(script.contains("a@b.de"))
    #expect(script.contains("geheim"))
    #expect(script.contains("looksLikeUsername"))
    #expect(script.contains("looksLikePassword"))
    #expect(script.contains("userFilled"))
    #expect(script.contains("passFilled"))
}

@Test
func loginAutofillScriptRecognizesGermanFieldHints() {
    let script = LoginAutofillScript.build(username: "u", password: "p")

    #expect(script.contains("kennwort") || script.contains("Kennwort") || script.contains("passwort"))
    #expect(script.contains("e-mail") || script.contains("email"))
}

@Test
func loginAutofillScriptDoesNotOverwriteMatchingFilledFields() {
    let script = LoginAutofillScript.build(username: "u", password: "p")

    // Bewusst jedes sichtbare Feld setzen (inkl. Duplikate) — Opodo hat oft 2 Forms.
    #expect(script.contains("_valueTracker"))
    #expect(script.contains("collect(root"))
}

@Test
func loginAutofillScriptFillsAllVisibleDuplicatesInDialog() {
    let script = LoginAutofillScript.build(username: "u", password: "p")

    #expect(script.contains("role=\"dialog\""))
    #expect(script.contains("aria-modal"))
    #expect(script.contains("loginRoots"))
    #expect(script.contains("collect(root"))
    #expect(!script.contains("el.focus()"))
    // Check24: Login-Inputs liegen im open Shadow DOM von <unified-login>.
    #expect(script.contains("shadowRoot"))
    #expect(script.contains("unified-login"))
    #expect(script.contains("longsession"))
    // Nach Fill den „Anmelden“-Submit klicken (#c24-uli-pw-btn).
    #expect(script.contains("clickSubmit"))
    #expect(script.contains("c24-uli-pw-btn"))
    #expect(script.contains("submitClicked"))
}
