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
