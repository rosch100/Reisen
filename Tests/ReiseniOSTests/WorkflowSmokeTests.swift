import XCTest

final class WorkflowSmokeTests: XCTestCase {
    func testHostBundleIdentifier() {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        XCTAssertNotNil(bundleIdentifier)
        XCTAssertTrue(bundleIdentifier?.hasSuffix(".Reisen.ios") == true)
    }
}
