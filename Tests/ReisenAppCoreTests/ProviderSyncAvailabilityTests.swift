import Testing
@testable import ReisenAppCore

struct ProviderSyncAvailabilityTests {
    @Test func canSyncRequiresAllPreconditions() {
        #expect(
            ProviderSyncAvailability.canSync(
                isProviderEnabled: true,
                hasWebView: true,
                hasRegistry: true,
                hasStore: true,
                isSyncing: false
            )
        )
    }

    @Test(arguments: [
        (false, true, true, true, false),
        (true, false, true, true, false),
        (true, true, false, true, false),
        (true, true, true, false, false),
        (true, true, true, true, true),
    ])
    func canSyncFalseWhenAnyGateFails(
        enabled: Bool,
        webView: Bool,
        registry: Bool,
        store: Bool,
        syncing: Bool
    ) {
        #expect(
            !ProviderSyncAvailability.canSync(
                isProviderEnabled: enabled,
                hasWebView: webView,
                hasRegistry: registry,
                hasStore: store,
                isSyncing: syncing
            )
        )
    }
}
