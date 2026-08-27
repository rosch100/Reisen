import XCTest
import CoreGraphics

@testable import ReiseniOSPrivate

final class WebViewHostFitTests: XCTestCase {
    func testProposedSizeUsesFinitePositiveDimensions() {
        let size = WebViewHostFit.proposedSize(width: 390, height: 500)
        XCTAssertEqual(size?.width, 390)
        XCTAssertEqual(size?.height, 500)
    }

    func testProposedSizeRejectsZeroUnspecifiedOrInfinite() {
        XCTAssertNil(WebViewHostFit.proposedSize(width: nil, height: 500))
        XCTAssertNil(WebViewHostFit.proposedSize(width: 390, height: nil))
        XCTAssertNil(WebViewHostFit.proposedSize(width: 0, height: 500))
        XCTAssertNil(WebViewHostFit.proposedSize(width: 390, height: .infinity))
    }
}
