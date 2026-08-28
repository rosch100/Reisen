import Foundation
import Testing
import ReisenAppCore

@Test func providerSessionStatus_fromProbe_mapsLoginState() {
    #expect(ProviderSessionStatus.fromProbe(loggedIn: true) == .sessionReady)
    #expect(ProviderSessionStatus.fromProbe(loggedIn: false) == .needsLogin)
}
