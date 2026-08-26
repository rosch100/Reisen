import Foundation
import Testing

@Test func macOSEntitlements_includeCalendarAndReminderSandboxAccess() throws {
    let entitlementsURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Tests/ReisenDomainTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("Resources/Reisen.entitlements")

    let data = try Data(contentsOf: entitlementsURL)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    let entitlements = try #require(plist as? [String: Any])

    #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
    #expect(entitlements["com.apple.security.personal-information.calendars"] as? Bool == true)
    #expect(entitlements["com.apple.security.personal-information.reminders"] as? Bool == true)
}
