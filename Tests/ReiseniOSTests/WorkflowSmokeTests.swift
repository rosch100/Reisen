import XCTest

final class WorkflowSmokeTests: XCTestCase {
    func testHostBundleIdentifier() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "de.roschmac.Reisen.ios")
    }
}
