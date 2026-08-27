import Foundation
import Testing

private func repoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func privacyManifest() throws -> [String: Any] {
    let url = repoRoot().appendingPathComponent("Resources/PrivacyInfo.xcprivacy")
    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let dict = plist as? [String: Any] else {
        throw NSError(domain: "PrivacyManifestFileTests", code: 1)
    }
    return dict
}

private func collectedTypes(_ plist: [String: Any]) -> [String] {
    let entries = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
    return entries.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
}

@Test func privacyManifest_declaresNoTrackingAndRequiredReasonAPIs() throws {
    let plist = try privacyManifest()
    #expect(plist["NSPrivacyTracking"] as? Bool == false)
    #expect((plist["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)

    let apiTypes = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
    let categories = apiTypes.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
    #expect(categories.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    #expect(categories.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))
}

@Test func privacyManifest_declaresOffDeviceDataTypes() throws {
    let types = try collectedTypes(privacyManifest())
    for required in [
        "NSPrivacyCollectedDataTypeName",
        "NSPrivacyCollectedDataTypeDateOfBirth",
        "NSPrivacyCollectedDataTypePhysicalAddress",
        "NSPrivacyCollectedDataTypeUserID",
        "NSPrivacyCollectedDataTypeOtherUserContent",
        "NSPrivacyCollectedDataTypeCustomerSupport",
        "NSPrivacyCollectedDataTypeCrashData",
        "NSPrivacyCollectedDataTypeOtherDiagnosticData",
    ] {
        #expect(types.contains(required), "Missing \(required)")
    }
    #expect(!types.contains("NSPrivacyCollectedDataTypeUserContent"))
    #expect(!types.contains("NSPrivacyCollectedDataTypeEmailAddress"))
    #expect(!types.contains("NSPrivacyCollectedDataTypeDeviceID"))
}

@Test func privacyManifest_storeOmitsProviderEmailAndKeepsIssueTypes() throws {
    let url = repoRoot().appendingPathComponent("Apps/ReiseniOS/PrivacyInfo.xcprivacy")
    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let dict = plist as? [String: Any] else {
        throw NSError(domain: "PrivacyManifestFileTests", code: 2)
    }
    let types = collectedTypes(dict)
    #expect(!types.contains("NSPrivacyCollectedDataTypeEmailAddress"))
    #expect(types.contains("NSPrivacyCollectedDataTypeCrashData"))
    let apiTypes = dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
    let categories = apiTypes.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
    #expect(categories.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))
}

@Test func privacyManifest_privateDeclaresProviderEmail() throws {
    let url = repoRoot().appendingPathComponent("Apps/ReiseniOSPrivate/PrivacyInfo.xcprivacy")
    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let dict = plist as? [String: Any] else {
        throw NSError(domain: "PrivacyManifestFileTests", code: 3)
    }
    let types = collectedTypes(dict)
    #expect(types.contains("NSPrivacyCollectedDataTypeEmailAddress"))
    #expect(types.contains("NSPrivacyCollectedDataTypeCrashData"))
}
