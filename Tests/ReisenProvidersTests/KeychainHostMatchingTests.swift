import Testing
import ReisenProviders

@Test
func keychainHostCandidatesIncludeParentDomain() {
    let candidates = KeychainHostMatching.candidates(for: "kundenbereich.check24.de")
    #expect(candidates.contains("kundenbereich.check24.de"))
    #expect(candidates.contains("check24.de"))
    #expect(candidates.first == "kundenbereich.check24.de")
}

@Test
func keychainHostCandidatesForApexDomain() {
    let candidates = KeychainHostMatching.candidates(for: "check24.de")
    #expect(candidates == ["check24.de"])
}

@Test
func keychainHostMatchingAcceptsSubdomains() {
    #expect(KeychainHostMatching.server("check24.de", matches: "check24.de"))
    #expect(KeychainHostMatching.server("kundenbereich.check24.de", matches: "check24.de"))
    #expect(KeychainHostMatching.server("www.check24.de", matches: "check24.de"))
    #expect(KeychainHostMatching.server("secure.booking.com", matches: "booking.com"))
    #expect(!KeychainHostMatching.server("check24.com", matches: "check24.de"))
    #expect(!KeychainHostMatching.server("notcheck24.de", matches: "check24.de"))
}
