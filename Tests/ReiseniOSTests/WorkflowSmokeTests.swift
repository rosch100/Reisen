import XCTest

final class WorkflowSmokeTests: XCTestCase {
    func testHostBundleIdentifier() {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        XCTAssertNotNil(bundleIdentifier)
        XCTAssertEqual(bundleIdentifier, "app.voyenna.reisen.ios")
    }
}
