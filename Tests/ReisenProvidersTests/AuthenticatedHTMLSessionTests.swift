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

@Test("AuthenticatedHTMLSession wirft notEstablished bei Login-HTML")
func authenticatedHTMLSessionRejectsLoginHTML() {
    let response = HTTPURLResponse(
        url: URL(string: "https://example.com/login")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    let html = #"<html><body><input type="password"></body></html>"#.data(using: .utf8)!

    #expect(throws: AuthenticatedSessionError.notEstablished) {
        try AuthenticatedHTMLSession.validatedUTF8HTML(
            data: html,
            response: response,
            isLoginHTML: { _ in true }
        )
    }
}
