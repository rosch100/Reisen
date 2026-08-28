import Testing
import Foundation
import ReisenProviders
@testable import ReisenGetYourGuide

@Test("GetYourGuide passwordless OTP ohne Passwort-Feld ist Login")
func gygLooksLikeLoginHTMLPasswordless() {
    let loginHTML = """
    <html><body>
    <script src="/tf/assets/compiled/client/otp-centric-login-wrapper-v01.js"></script>
    <form action="/auth/passwordless/otp/send">
    <input type="email" name="email">
    </form>
    </body></html>
    """
    #expect(GetYourGuideInitialState.looksLikeLoginHTML(loginHTML))
}

@Test("GetYourGuide leeres myBookings-Objekt ist Session, kein Login")
func gygLooksLikeLoginHTMLTreatsEmptyMyBookingsAsAuthenticated() {
    #expect(!GetYourGuideInitialState.looksLikeLoginHTML(GetYourGuideResearchFixture.initialStateHTML(#"{"myBookings":{}}"#)))
}

@Test("GetYourGuide Login-SSR ohne passwordless-Chunk ist Login")
func gygLooksLikeLoginHTMLWithoutPasswordlessChunks() {
    #expect(GetYourGuideInitialState.looksLikeLoginHTML(GetYourGuideResearchFixture.initialStateHTML(gygLoginSSRJSON)))
}

@Test("GetYourGuide Detail mit bookingSummary ist kein Login")
func gygLooksLikeLoginHTMLRejectsBookingSummary() {
    #expect(!GetYourGuideInitialState.looksLikeLoginHTML(GetYourGuideResearchFixture.initialStateHTML(#"{"booking":{"bookingSummary":{}}}"#)))
}

@Test("GetYourGuide Asset-Substring ist kein Session-Key in __INITIAL_STATE__")
func gygLooksLikeLoginHTMLIgnoresAssetSubstrings() {
    let html = """
    <script src="/assets/bookingSummary-chunk.js"></script>
    <script src="/assets/my-bookings.js"></script>
    """ + GetYourGuideResearchFixture.initialStateHTML(gygLoginSSRJSON)
    #expect(GetYourGuideInitialState.looksLikeLoginHTML(html))
}

@Test("AuthenticatedHTMLSession erkennt GYG-Catalog-200 ohne myBookings als fehlende Session")
func gygAuthenticatedHTMLSessionRejectsCatalogLoginState() {
    expectAuthenticatedHTML(
        status: 200,
        html: GetYourGuideResearchFixture.initialStateHTML(#"{"locale":"en-US"}"#),
        error: .notEstablished
    )
}

@Test("AuthenticatedHTMLSession erkennt GYG-403-Challenge als Cloudflare")
func gygAuthenticatedHTMLSessionRejects403CloudflareChallenge() {
    expectAuthenticatedHTML(
        status: 403,
        html: GetYourGuideResearchFixture.cloudflareChallengeHTML,
        error: .challenge,
        isChallengeHTML: GetYourGuideInitialState.looksLikeCloudflareChallenge
    )
}

private func expectAuthenticatedHTML(
    status: Int,
    html: String,
    error: AuthenticatedSessionError,
    isChallengeHTML: ((String) -> Bool)? = nil
) {
    let (data, response) = catalogHTMLResponse(status: status, html: html)
    #expect(throws: error) {
        try AuthenticatedHTMLSession.validatedUTF8HTML(
            data: data,
            response: response,
            isLoginHTML: GetYourGuideInitialState.looksLikeLoginHTML,
            isChallengeHTML: isChallengeHTML
        )
    }
}

private func catalogHTMLResponse(status: Int, html: String) -> (Data, HTTPURLResponse) {
    let response = HTTPURLResponse(
        url: GetYourGuideWebConstants.catalogSyncURL,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
    )!
    return (Data(html.utf8), response)
}

private let gygLoginSSRJSON = #"{"locale":"de-DE","user":{}}"#
