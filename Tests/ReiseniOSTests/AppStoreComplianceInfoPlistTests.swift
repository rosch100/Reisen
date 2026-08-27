import XCTest

final class AppStoreComplianceInfoPlistTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testInfoPlistHasExportComplianceAndBackgroundMode() throws {
        let plistURL = repoRoot.appendingPathComponent("Apps/ReiseniOS/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["ITSAppUsesNonExemptEncryption"] as? Bool, false)

        let backgroundModes = plist["UIBackgroundModes"] as? [String]
        XCTAssertEqual(backgroundModes, ["remote-notification"])
    }

    func testInfoPlistHasNoProviderQuerySchemes() throws {
        let plistURL = repoRoot.appendingPathComponent("Apps/ReiseniOS/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertNil(plist["LSApplicationQueriesSchemes"])
    }

    func testPrivacyManifestExists() throws {
        let privacyURL = repoRoot.appendingPathComponent("Resources/PrivacyInfo.xcprivacy")
        XCTAssertTrue(FileManager.default.fileExists(atPath: privacyURL.path))

        let data = try Data(contentsOf: privacyURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        let collected = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        let types = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertTrue(types.contains("NSPrivacyCollectedDataTypeName"))
        XCTAssertTrue(types.contains("NSPrivacyCollectedDataTypeCrashData"))
        XCTAssertFalse(types.contains("NSPrivacyCollectedDataTypeEmailAddress"))
    }

    func testStorePrivacyManifestOmitsProviderEmail() throws {
        let privacyURL = repoRoot.appendingPathComponent("Apps/ReiseniOS/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: privacyURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let collected = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        let types = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertFalse(types.contains("NSPrivacyCollectedDataTypeEmailAddress"))
    }

    func testReleaseEntitlementsUseProductionPush() throws {
        let entitlementsURL = repoRoot.appendingPathComponent("Apps/ReiseniOS/ReiseniOS-Release.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["aps-environment"] as? String, "production")
        XCTAssertNil(plist["com.apple.developer.ubiquity-kvstore-identifier"])
    }

    func testDebugEntitlementsHaveNoKVS() throws {
        let entitlementsURL = repoRoot.appendingPathComponent("Apps/ReiseniOS/ReiseniOS.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertNil(plist["com.apple.developer.ubiquity-kvstore-identifier"])
        XCTAssertEqual(plist["aps-environment"] as? String, "development")
    }

    func testMacEntitlementsOmitUnusedFileAccess() throws {
        let entitlementsURL = repoRoot.appendingPathComponent("Resources/Reisen.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertNil(plist["com.apple.security.files.user-selected.read-write"])
    }

    func testAppIconAssetCatalogExists() throws {
        let iconPNG = repoRoot
            .appendingPathComponent("Apps/ReiseniOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconPNG.path))
    }
}
