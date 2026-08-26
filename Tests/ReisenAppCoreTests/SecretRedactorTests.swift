import Testing
@testable import ReisenAppCore

@Test func secretRedactor_redactsBearerAndGithubPats() {
    let input = """
    Fehler: Authorization: Bearer ghp_abcdefghijklmnopqrstuvwxyz0123456789
    Token github_pat_11AAAAAAA0123456789abcdefghijklmnopqrstuv
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("ghp_abcdefghijklmnopqrstuvwxyz0123456789"))
    #expect(!redacted.contains("github_pat_11AAAAAAA0123456789abcdefghijklmnopqrstuv"))
    #expect(!redacted.contains("Bearer ghp_"))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_redactsCookieAndQuerySecrets() {
    let input = """
    Cookie: session=abc123; other=ok
    https://example.com/callback?code=secretcode&token=abc&session=xyz&password=pw&keep=1
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("abc123"))
    #expect(!redacted.contains("secretcode"))
    #expect(redacted.contains("[redacted]"))
    #expect(redacted.contains("keep=1"))
}

@Test func secretRedactor_redactsTravelokaSessionCookiesWithoutCookieHeader() {
    let input = """
    sen_t=sentinel-secret tvs=tvsession tvl=tvlogin tvo=tvother clientSessionId=01ABC
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("sentinel-secret"))
    #expect(!redacted.contains("tvsession"))
    #expect(!redacted.contains("tvlogin"))
    #expect(!redacted.contains("tvother"))
    #expect(!redacted.contains("01ABC"))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_redactsJSONSessionTokens() {
    let input = """
    {"token":"json-secret","access_token":"atk","session":"sess","password":"pw","keep":"ok"}
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("json-secret"))
    #expect(!redacted.contains("atk"))
    #expect(!redacted.contains("\"sess\""))
    #expect(!redacted.contains("\"pw\""))
    #expect(redacted.contains("\"keep\":\"ok\""))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_keepsErrorAndFeedbackTextIncludingEmail() {
    let input = "Sync fehlgeschlagen: Session abgelaufen. Rückmeldung an test@example.com"
    let redacted = SecretRedactor.redact(input)
    #expect(redacted.contains("Sync fehlgeschlagen: Session abgelaufen."))
    #expect(redacted.contains("test@example.com"))
}
