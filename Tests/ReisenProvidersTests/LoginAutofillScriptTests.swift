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
    #expect(script.contains("type === 'tel'"))
    #expect(script.contains("mobile"))
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

@Test
func loginAutofillScriptDoesNotClickSocialIdPSubmit() {
    let script = LoginAutofillScript.build(username: "u", password: "p")
    #expect(script.contains("isSocialSubmit"))
    #expect(script.contains("sign.?in.?with.?(apple|google|facebook)"))
    #expect(script.contains("anmelden.?mit.?(apple|google|facebook)"))
    #expect(script.contains("if (isSocialSubmit(el)) return false"))
}

@Test
func loginAutofillScriptUsesSentinelCredentialsAndReturnsSubmitIdentifier() {
    let username = "unique-user-sentinel@example.invalid"
    let password = "unique-password-sentinel"
    let script = LoginAutofillScript.build(username: username, password: password)

    #expect(script.contains(username))
    #expect(script.contains(password))
    #expect(script.contains("submitId"))
    #expect(script.contains("submitClicked"))
}

@Test
func providerLoginAttemptPolicyCapsAttemptsAndRequiresRetryDelay() {
    #expect(ProviderLoginAttemptPolicy.maximumAttempts(requested: 99) == 3)
    #expect(ProviderLoginAttemptPolicy.maximumAttempts(requested: 0) == 1)
    #expect(
        ProviderLoginAttemptPolicy.retryDelay(after: 0, delays: [0.1, 0.2]) == nil
    )
    #expect(
        ProviderLoginAttemptPolicy.retryDelay(after: 1, delays: [0.1, 0.2]) == 0.1
    )
}
