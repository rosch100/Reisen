import Testing
import Foundation
import ReisenProviders

@Test("AuthenticatedSessionGuard erkennt 401/403")
func authenticatedSessionGuardUnauthorizedHTTP() {
    #expect(AuthenticatedSessionGuard.isUnauthorizedHTTP(401))
    #expect(AuthenticatedSessionGuard.isUnauthorizedHTTP(403))
    #expect(!AuthenticatedSessionGuard.isUnauthorizedHTTP(200))
    #expect(AuthenticatedSessionGuard.isUnauthorized(.httpStatus(401)))
    #expect(!AuthenticatedSessionGuard.isUnauthorized(.httpStatus(500)))
}

@Test("AuthenticatedHTMLSession erkennt GYG-Login-Redirect ohne Passwort-Feld")
func authenticatedHTMLSessionRejectsGetYourGuideLoginRedirect() {
    let (html, response) = htmlResponse(
        url: "https://www.getyourguide.com/login",
        status: 200,
        html: #"<html><body><input type="email"></body></html>"#
    )
    #expect(throws: AuthenticatedSessionError.notEstablished) {
        try AuthenticatedHTMLSession.validatedUTF8HTML(
            data: html,
            response: response,
            isLoginHTML: { _ in false }
        )
    }
}

@Test("AuthenticatedHTMLSession wirft notEstablished bei Login-HTML")
func authenticatedHTMLSessionRejectsLoginHTML() {
    let (html, response) = htmlResponse(status: 200, html: #"<html><body><input type="password"></body></html>"#)
    #expect(throws: AuthenticatedSessionError.notEstablished) {
        try AuthenticatedHTMLSession.validatedUTF8HTML(
            data: html,
            response: response,
            isLoginHTML: { _ in true }
        )
    }
}

@Test(
    "AuthenticatedHTMLSession wirft challenge bei Challenge-HTML",
    arguments: [
        (200, "https://example.com/account"),
        (200, "https://www.getyourguide.com/login"),
        (403, "https://example.com/account"),
    ]
)
func authenticatedHTMLSessionRejectsChallengeHTML(status: Int, url: String) {
    let (html, response) = htmlResponse(url: url, status: status, html: challengeHTML)
    #expect(throws: AuthenticatedSessionError.challenge) {
        try AuthenticatedHTMLSession.validatedUTF8HTML(
            data: html,
            response: response,
            isLoginHTML: { _ in false },
            isChallengeHTML: looksLikeChallenge
        )
    }
}

@Test("AuthenticatedHTMLSession 403 ohne Challenge-Callback bleibt notEstablished")
func authenticatedHTMLSession403WithoutChallengeCallbackStaysNotEstablished() {
    let (html, response) = htmlResponse(status: 403, html: challengeHTML)
    #expect(throws: AuthenticatedSessionError.notEstablished) {
        try AuthenticatedHTMLSession.validatedUTF8HTML(
            data: html,
            response: response,
            isLoginHTML: { _ in false }
        )
    }
}

private let challengeHTML = #"<html><div id="challenge-stage"></div></html>"#

private func looksLikeChallenge(_ html: String) -> Bool {
    html.contains("challenge-stage")
}

private func htmlResponse(
    url: String = "https://example.com/account",
    status: Int,
    html: String
) -> (Data, HTTPURLResponse) {
    let response = HTTPURLResponse(
        url: URL(string: url)!,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
    )!
    return (Data(html.utf8), response)
}
