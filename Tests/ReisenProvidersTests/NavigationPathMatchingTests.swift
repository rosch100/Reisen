import Testing
import ReisenProviders

@Test("Root-Pfad matcht nicht jedes Secure-Ziel")
func rootPathDoesNotMatchSecureTripDetails() {
    #expect(NavigationPathMatching.pathsMatch(currentPath: "/", targetPath: "/") == true)
    #expect(
        NavigationPathMatching.pathsMatch(currentPath: "/", targetPath: "/travel/secure") == false
    )
    #expect(
        NavigationPathMatching.pathsMatch(currentPath: "/travel/secure", targetPath: "/travel/secure")
            == true
    )
    #expect(
        NavigationPathMatching.pathsMatch(
            currentPath: "/travel/secure",
            targetPath: "/travel/secure/extra"
        ) == true
    )
}
