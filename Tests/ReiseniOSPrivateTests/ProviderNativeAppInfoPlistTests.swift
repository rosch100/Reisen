import XCTest
import ReisenProviders

final class ProviderNativeAppInfoPlistTests: XCTestCase {
    func testLSApplicationQueriesSchemesMatchesCatalog() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Apps/ReiseniOSPrivate/Info.plist")

        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let schemes = plist?["LSApplicationQueriesSchemes"] as? [String]

        XCTAssertEqual(schemes, ProviderNativeApp.queryURLSchemes)
    }
}
