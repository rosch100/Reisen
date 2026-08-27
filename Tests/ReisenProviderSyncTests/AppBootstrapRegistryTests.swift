import Testing
import ReisenProviderSync
import ReisenDomain

@Test @MainActor func providerSyncBootstrapRegistry_matchesSyncProviderIDsSSOT() {
    let registry = ProviderSyncBootstrap.makeProviderRegistry()
    #expect(registry.syncProviderIDs == ProviderID.syncProviderIDs)
}
