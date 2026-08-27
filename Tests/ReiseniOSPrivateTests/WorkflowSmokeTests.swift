import XCTest
import ReisenProviderSync
import ReisenDomain

final class WorkflowSmokeTests: XCTestCase {
    func testHostBundleIdentifier() {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        XCTAssertNotNil(bundleIdentifier)
        XCTAssertTrue(bundleIdentifier?.hasSuffix(".Reisen.ios.private") == true)
    }

    @MainActor
    func testProviderSyncBootstrapExposesAllSyncProviders() {
        let registry = ProviderSyncBootstrap.makeProviderRegistry()
        XCTAssertEqual(registry.syncProviderIDs, ProviderID.syncProviderIDs)
        XCTAssertFalse(registry.deepLinkBuilders.isEmpty)
    }
}
