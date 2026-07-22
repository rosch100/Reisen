import Testing
import ReisenProviders

@Test
func keychainCredentialAccountIDIsStable() {
    let account = KeychainCredentialAccount(serverHost: "booking.com", username: "a@b.de")
    #expect(account.id == "booking.com\u{1f}a@b.de")
    #expect(account.displayTitle == "a@b.de")
    #expect(account.displaySubtitle == "booking.com")
}

@Test
func keychainCredentialAccountEqualityIgnoresDisplayHelpers() {
    let a = KeychainCredentialAccount(serverHost: "opodo.de", username: "x@y.de")
    let b = KeychainCredentialAccount(serverHost: "opodo.de", username: "x@y.de")
    let c = KeychainCredentialAccount(serverHost: "opodo.de", username: "other@y.de")
    #expect(a == b)
    #expect(a.id == b.id)
    #expect(a != c)
}
