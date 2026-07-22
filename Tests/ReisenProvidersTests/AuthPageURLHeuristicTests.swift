import Testing
import ReisenProviders

@Test func loginPageIsDetected() {
    #expect(AuthPageURLHeuristic.looksLikeLoginPage("https://kundenbereich.check24.de/user/login.html"))
    #expect(AuthPageURLHeuristic.looksLikeLoginPage("https://example.com/anmelden"))
    #expect(AuthPageURLHeuristic.looksLikeLoginPage("https://account.booking.com/sign-in"))
    #expect(!AuthPageURLHeuristic.looksLikeLoginPage("https://kundenbereich.check24.de/account/activities"))
    // Host `secure.booking.com` darf nicht als Login gelten (Substring "//secure").
    #expect(!AuthPageURLHeuristic.looksLikeLoginPage("https://secure.booking.com/mytrips.de.html"))
    // Opodo Secure ist My-Trips (Account), nicht der PasswordLogin-Einstieg.
    #expect(!AuthPageURLHeuristic.looksLikeLoginPage("https://www.opodo.de/travel/secure/"))
    #expect(!AuthPageURLHeuristic.looksLikeLoginPage("https://www.opodo.de/"))
}

@Test func otpChallengeIsDetected() {
    #expect(AuthPageURLHeuristic.looksLikeOneTimeCodeChallenge("https://example.com/auth/otp"))
    #expect(AuthPageURLHeuristic.looksLikeOneTimeCodeChallenge("https://example.com/mfa/verify"))
    #expect(AuthPageURLHeuristic.looksLikeOneTimeCodeChallenge("https://example.com/sicherheitscode"))
    #expect(!AuthPageURLHeuristic.looksLikeOneTimeCodeChallenge("https://kundenbereich.check24.de/account/activities"))
}

@Test func accountPageIsDetected() {
    #expect(AuthPageURLHeuristic.looksLikeAccountPage("https://kundenbereich.check24.de/account/activities"))
    #expect(AuthPageURLHeuristic.looksLikeAccountPage("https://www.booking.com/my-bookings"))
    #expect(AuthPageURLHeuristic.looksLikeAccountPage("https://secure.booking.com/mytrips.de.html"))
    #expect(AuthPageURLHeuristic.looksLikeAccountPage("https://www.opodo.de/travel/secure/"))
    #expect(!AuthPageURLHeuristic.looksLikeAccountPage("https://example.com/pricing"))
}

@Test func opodoSecureIsSessionReadyNotLogin() {
    let url = "https://www.opodo.de/travel/secure/"
    #expect(AuthPageURLHeuristic.looksLikeAccountPage(url))
    #expect(!AuthPageURLHeuristic.looksLikeLoginPage(url))
}

@Test func bookingMyTripsIsSessionReadyNotLogin() {
    let url = "https://secure.booking.com/mytrips.de.html?auth_success=1"
    #expect(AuthPageURLHeuristic.looksLikeAccountPage(url))
    #expect(!AuthPageURLHeuristic.looksLikeLoginPage(url))
}

@Test func check24AccountPageIgnoresLoginInQueryParams() {
    // Nach SSO bleiben oft context_ref/callback mit …/login.html in der Query —
    // das darf die eingeloggte Kundenbereich-Seite nicht als Login klassifizieren.
    let url = "https://m.check24.de/kundenbereich/actions/all"
        + "?context_ref=https%3A%2F%2Fkundenbereich.check24.de%2Fuser%2Flogin.html"
        + "&api_product=check24_sso"
    #expect(AuthPageURLHeuristic.looksLikeAccountPage(url))
    #expect(!AuthPageURLHeuristic.looksLikeLoginPage(url))
}

@Test func check24LoginPathStillDetectedDespiteAccountHost() {
    #expect(AuthPageURLHeuristic.looksLikeLoginPage("https://m.check24.de/kundenbereich/login"))
    #expect(AuthPageURLHeuristic.looksLikeLoginPage(
        "https://kundenbereich.check24.de/user/login.html?api_product=check24_sso"
    ))
}

@Test func check24SSOAuthPrepareIsLoginNotAccount() {
    let url = "https://accounts.check24.de/auth/prepare"
        + "?api_product=check24_sso"
        + "&callback=https%3A%2F%2Fkundenbereich.check24.de%2Fuser%2Faccount%2Factivities.html"
    #expect(AuthPageURLHeuristic.looksLikeLoginPage(url))
    #expect(!AuthPageURLHeuristic.looksLikeAccountPage(url))
}

@Test func bookingAccountHostStillCountsAsAccountPage() {
    #expect(AuthPageURLHeuristic.looksLikeAccountPage("https://account.booking.com/my-settings"))
}

@Test func oneTimeCodeAutofillHelperCoversLoginOrOTP() {
    #expect(AuthPageURLHeuristic.shouldApplyOneTimeCodeAutofill("https://example.com/user/login"))
    #expect(AuthPageURLHeuristic.shouldApplyOneTimeCodeAutofill("https://example.com/2fa"))
    #expect(!AuthPageURLHeuristic.shouldApplyOneTimeCodeAutofill("https://www.opodo.de/travel/secure/"))
    #expect(!AuthPageURLHeuristic.shouldApplyOneTimeCodeAutofill("https://kundenbereich.check24.de/account/activities"))
}
