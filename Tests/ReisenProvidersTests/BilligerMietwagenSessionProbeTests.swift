import Foundation
import Testing
import ReisenProviders

@Test func billigerMietwagenSessionProbeAppliesToPortalHosts() {
    #expect(BilligerMietwagenSessionProbe.applies(to: URL(string: "https://www.billiger-mietwagen.de/")!))
    #expect(BilligerMietwagenSessionProbe.applies(to: URL(string: "https://billiger-mietwagen.de/reservation/account/login")!))
    #expect(!BilligerMietwagenSessionProbe.applies(to: URL(string: "https://kundenbereich.check24.de/")!))
}

@Test func billigerMietwagenSessionProbeDetectsSessionTokenShape() {
    #expect(BilligerMietwagenSessionProbe.isLoggedIn(fromSessionJSON: #"{"access_token":"<REDACTED>","refresh_token":"<REDACTED>"}"#) == true)
    #expect(BilligerMietwagenSessionProbe.isLoggedIn(fromSessionJSON: "{}") == false)
    #expect(BilligerMietwagenSessionProbe.isLoggedIn(fromSessionJSON: "[]") == false)
    #expect(BilligerMietwagenSessionProbe.isLoggedIn(fromSessionJSON: #"{"access_token":""}"#) == false)
    #expect(BilligerMietwagenSessionProbe.isLoggedIn(fromSessionJSON: #"{"access_token":"tok"}"#) == false)
    #expect(BilligerMietwagenSessionProbe.isLoggedIn(fromSessionJSON: #"{"refresh_token":"tok"}"#) == false)
}

@Test func billigerMietwagenAuthConstantsMatchLoginHAR() {
    #expect(BilligerMietwagenAuthConstants.whitelabel == "DE_billiger-mietwagen")
    #expect(BilligerMietwagenAuthConstants.loginAPIURL.absoluteString == "https://consumer-api.floyt.com/auth/v1/login")
    #expect(BilligerMietwagenAuthConstants.sessionURL.path == "/user_account/session.php")
    #expect(BilligerMietwagenAuthConstants.sessionReferer.contains("/reservation/account/bookings"))
    #expect(BilligerMietwagenAuthConstants.sessionProbeReferer == BilligerMietwagenAuthConstants.sessionReferer)
    #expect(BilligerMietwagenAuthConstants.jwtUsernameClaim == "username")
    #expect(BilligerMietwagenAuthConstants.spaClientID == "web")
    #expect(
        BilligerMietwagenAuthConstants.hasSessionTokens(
            inSessionJSON: #"{"access_token":"a","refresh_token":"r"}"#
        ) == true
    )
    let api = BilligerMietwagenAuthConstants.apiRequestHeaders(accessToken: "tok")
    #expect(api["X-Whitelabel"] == "DE_billiger-mietwagen")
    #expect(api["Authorization"] == "Bearer tok")
    #expect(api["client-id"] == "web")
    #expect(api["Origin"] == "https://www.billiger-mietwagen.de")
    let sessionHeaders = BilligerMietwagenAuthConstants.sessionBrowserHeaders
    #expect(sessionHeaders["client-id"] == "web")
    #expect(sessionHeaders["Origin"] == "https://www.billiger-mietwagen.de")
}

@Test func billigerMietwagenSessionProbeReprobesWhenSessionCookiesAppearAfterSPALogin() {
    #expect(
        BilligerMietwagenAuthConstants.sessionCookieNames == Set([
            "__Secure-billigermietwagen",
            "__Secure-user_account",
        ])
    )
    let afterLogin = BilligerMietwagenSessionProbe.shouldReprobeAfterCookieChange(
        previousPresence: [],
        currentCookies: [
            ("consent", true),
            ("__Secure-billigermietwagen", true),
            ("__Secure-user_account", true),
        ]
    )
    #expect(afterLogin.shouldReprobe == true)
    #expect(
        afterLogin.newPresence == [
            "__Secure-billigermietwagen",
            "__Secure-user_account",
        ]
    )

    let unchanged = BilligerMietwagenSessionProbe.shouldReprobeAfterCookieChange(
        previousPresence: afterLogin.newPresence,
        currentCookies: [
            ("consent", true),
            ("__Secure-billigermietwagen", true),
            ("__Secure-user_account", true),
        ]
    )
    #expect(unchanged.shouldReprobe == false)
    #expect(unchanged.newPresence == afterLogin.newPresence)

    let emptySessionCookies = BilligerMietwagenSessionProbe.shouldReprobeAfterCookieChange(
        previousPresence: [],
        currentCookies: [
            ("__Secure-billigermietwagen", false),
            ("__Secure-user_account", false),
        ]
    )
    #expect(emptySessionCookies.shouldReprobe == false)
    #expect(emptySessionCookies.newPresence.isEmpty)

    let filledAfterEmpty = BilligerMietwagenSessionProbe.shouldReprobeAfterCookieChange(
        previousPresence: emptySessionCookies.newPresence,
        currentCookies: [
            ("__Secure-billigermietwagen", true),
            ("__Secure-user_account", true),
        ]
    )
    #expect(filledAfterEmpty.shouldReprobe == true)

    let onlyUnrelated = BilligerMietwagenSessionProbe.shouldReprobeAfterCookieChange(
        previousPresence: [],
        currentCookies: [("consent", true), ("_ga", true)]
    )
    #expect(onlyUnrelated.shouldReprobe == false)
    #expect(onlyUnrelated.newPresence.isEmpty)

    let afterLogout = BilligerMietwagenSessionProbe.shouldReprobeAfterCookieChange(
        previousPresence: afterLogin.newPresence,
        currentCookies: [("consent", true)]
    )
    #expect(afterLogout.shouldReprobe == true)
    #expect(afterLogout.newPresence.isEmpty)
}

@MainActor
@Test func billigerMietwagenSessionCookieObserverApplyCookiesTracksPresenceChanges() {
    var fired = 0
    let observer = BilligerMietwagenSessionCookieObserver { fired += 1 }
    func cookie(_ name: String, value: String) -> HTTPCookie {
        HTTPCookie(properties: [
            .domain: "www.billiger-mietwagen.de",
            .path: "/",
            .name: name,
            .value: value,
            .secure: "TRUE",
        ])!
    }

    #expect(observer.applyCookies([cookie("consent", value: "1")]) == false)
    #expect(
        observer.applyCookies([
            cookie("consent", value: "1"),
            cookie("__Secure-billigermietwagen", value: "tok"),
            cookie("__Secure-user_account", value: "acc"),
        ]) == true
    )
    #expect(
        observer.applyCookies([
            cookie("__Secure-billigermietwagen", value: "tok"),
            cookie("__Secure-user_account", value: "acc"),
        ]) == false
    )
    #expect(observer.applyCookies([cookie("consent", value: "1")]) == true)
    #expect(fired == 0)
}
