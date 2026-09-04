import XCTest
import ReisenProviderSync
import ReisenDomain

final class WorkflowSmokeTests: XCTestCase {
    func testHostBundleIdentifier() {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        XCTAssertNotNil(bundleIdentifier)
        XCTAssertEqual(bundleIdentifier, "app.voyenna.reisen.ios.private")
    }

    @MainActor
    func testProviderSyncBootstrapExposesAllSyncProviders() {
        let registry = ProviderSyncBootstrap.makeProviderRegistry()
        XCTAssertEqual(registry.syncProviderIDs, ProviderID.syncProviderIDs)
        XCTAssertFalse(registry.deepLinkBuilders.isEmpty)
    }
}
