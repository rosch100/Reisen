import Testing
import ReisenProviders

@Test
func oneTimeCodeAutofillScriptMarksOTPAndWalksShadowDOM() {
    let script = OneTimeCodeAutofillScript.build()

    #expect(script.contains("one-time-code"))
    #expect(script.contains("autocomplete"))
    #expect(script.contains("shadowRoot"))
    #expect(script.contains("unified-login"))
    #expect(script.contains("walkOpenShadowRoots"))
    #expect(script.contains("__reisenOTCInstalled"))
}

@Test
func oneTimeCodeAutofillScriptEnablesPasteAndSplitFieldFill() {
    let script = OneTimeCodeAutofillScript.build()

    #expect(script.contains("paste"))
    #expect(script.contains("clipboardData"))
    #expect(script.contains("maxlength"))
    #expect(script.contains("distributeDigits"))
    #expect(script.contains("splitOTPGroup"))
    #expect(script.contains("prepareSplitGroup"))
    #expect(script.contains("if (!looksLikeOTP(el)) return false"))
    #expect(!script.contains("first.setAttribute('maxlength'"))
}

@Test
func oneTimeCodeAutofillScriptRelaxesSplitMaxLengthOnlyWhenRequested() {
    let ios = OneTimeCodeAutofillScript.build(relaxSplitFieldMaxLength: true)
    #expect(ios.contains("if (!looksLikeOTP(el)) return false"))
    #expect(ios.contains("first.setAttribute('maxlength'"))
}

@Test
func oneTimeCodeAutofillScriptDoesNotTargetPasswordFields() {
    let script = OneTimeCodeAutofillScript.build()

    #expect(script.contains("current-password"))
    #expect(script.contains("isExcluded"))
    #expect(script.contains("password"))
}
