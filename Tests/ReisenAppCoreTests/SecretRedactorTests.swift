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

@Test func secretRedactor_redactsAuthorizationSchemesAndGithubAppTokens() {
    let input = """
    Authorization: Basic dXNlcjpwYXNzd29ydA==
    gho_abcdefghijklmnopqrstuvwxyz0123456789
    ghu_abcdefghijklmnopqrstuvwxyz0123456789
    ghs_abcdefghijklmnopqrstuvwxyz0123456789
    ghr_abcdefghijklmnopqrstuvwxyz0123456789
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("dXNlcjpwYXNzd29ydA=="))
    #expect(!redacted.contains("gho_abcdefghijklmnopqrstuvwxyz0123456789"))
    #expect(!redacted.contains("ghu_abcdefghijklmnopqrstuvwxyz0123456789"))
    #expect(!redacted.contains("ghs_abcdefghijklmnopqrstuvwxyz0123456789"))
    #expect(!redacted.contains("ghr_abcdefghijklmnopqrstuvwxyz0123456789"))
    #expect(redacted.contains("Authorization: Basic [redacted]"))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_redactsCookieAndQuerySecrets() {
    let input = """
    Cookie: session=abc123; other=ok
    https://example.com/callback?code=secretcode&token=abc&session=xyz&password=pw&keep=1
    https://example.com/oauth?access_token=atk&refresh_token=rtk&id_token=idt&api_key=key1&apikey=key2&client_secret=cs&keep=1
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("abc123"))
    #expect(!redacted.contains("secretcode"))
    #expect(!redacted.contains("atk"))
    #expect(!redacted.contains("rtk"))
    #expect(!redacted.contains("idt"))
    #expect(!redacted.contains("key1"))
    #expect(!redacted.contains("key2"))
    #expect(!redacted.contains("cs"))
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

@Test func secretRedactor_keepsErrorTextAndRedactsEmailAddresses() {
    let input = "Sync fehlgeschlagen: Session abgelaufen. Rückmeldung an test@example.com"
    let redacted = SecretRedactor.redact(input)
    #expect(redacted.contains("Sync fehlgeschlagen: Session abgelaufen."))
    #expect(!redacted.contains("test@example.com"))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_redactsLabeledBookingReferences() {
    let input = """
    Buchungsnummer: AB12CD Fehlgeschlagen.
    confirmationCode=XYZ987 und PNR: QWE123
    {"confirmationCode":"SECRET99","keep":"ok"}
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("AB12CD"))
    #expect(!redacted.contains("XYZ987"))
    #expect(!redacted.contains("QWE123"))
    #expect(!redacted.contains("SECRET99"))
    #expect(redacted.contains("keep"))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_redactsPassengerIdentityAndContactPII() {
    let input = """
    Parse fehlgeschlagen: Vorname: Erika Nachname: Mustermann
    Telefon: +49 171 1234567 Adresse: Lindenstraße 12
    Geburtsdatum: 1990-04-01 Passnummer: C01X00T47
    {"givenName":"Erika","familyName":"Mustermann","birthDate":"1990-04-01","phone":"+491711234567","keep":"ok"}
    https://example.com/x?firstName=Erika&lastName=Mustermann&phone=%2B49171&keep=1
    IBAN DE89370400440532013000
    """
    let redacted = SecretRedactor.redact(input)
    #expect(redacted.contains("Parse fehlgeschlagen:"))
    #expect(!redacted.contains("Erika"))
    #expect(!redacted.contains("Mustermann"))
    #expect(!redacted.contains("171 1234567"))
    #expect(!redacted.contains("Lindenstraße 12"))
    #expect(!redacted.contains("1990-04-01"))
    #expect(!redacted.contains("C01X00T47"))
    #expect(!redacted.contains("DE89370400440532013000"))
    #expect(redacted.contains("\"keep\":\"ok\""))
    #expect(redacted.contains("keep=1"))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_redactsJSONPersonNameFieldsNotGenericName() {
    let input = """
    {"name":"Sommerurlaub","fullName":"Max Beispiel","displayName":"Ada","keep":"ok"}
    """
    let redacted = SecretRedactor.redact(input)
    #expect(redacted.contains("Sommerurlaub"))
    #expect(!redacted.contains("Max Beispiel"))
    #expect(!redacted.contains("Ada"))
    #expect(redacted.contains("\"keep\":\"ok\""))
    #expect(redacted.contains("[redacted]"))
}

@Test func secretRedactor_redactsHomeDirectoryPathsInStacks() {
    let input = """
    0   Reisen  0x0000000102a3c000 /Users/roschmac/Library/Developer/Reisen.debug.dylib
    1   Reisen  0x0000000102a3c100 file:///Users/roschmac/Entwicklung/Reisen/Sources/App.swift
    2   libc    0x0000000000000000 /home/alice/app/lib.so
    """
    let redacted = SecretRedactor.redact(input)
    #expect(!redacted.contains("roschmac"))
    #expect(!redacted.contains("/home/alice"))
    #expect(redacted.contains("/Users/[redacted]/Library/Developer/Reisen.debug.dylib"))
    #expect(redacted.contains("file:///Users/[redacted]/Entwicklung/Reisen/Sources/App.swift"))
    #expect(redacted.contains("/home/[redacted]/app/lib.so"))
    #expect(redacted.contains("0x0000000102a3c000"))
}
