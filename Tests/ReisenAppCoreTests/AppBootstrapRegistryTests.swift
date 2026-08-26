import Testing
import ReisenAppCore
import ReisenDomain

@Test @MainActor func appBootstrapRegistry_matchesSyncProviderIDsSSOT() {
    let registry = AppBootstrap.makeProviderRegistry()
    #expect(registry.syncProviderIDs == ProviderID.syncProviderIDs)
}
