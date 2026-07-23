import XCTest
import ReisenDomain

final class WorkflowSmokeTests: XCTestCase {
    func testProviderIDRawValueRoundTrip() {
        let id = ProviderID(rawValue: "check24")
        XCTAssertEqual(id.rawValue, "check24")
    }
}
