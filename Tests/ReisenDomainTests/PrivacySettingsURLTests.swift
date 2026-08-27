import Testing
import Foundation
import ReisenDomain

@Test func privacySettingsURL_calendars_opensPrivacyCalendarsPane() {
    let urls = PrivacySettingsURL.macOSCandidates(for: .calendars)

    #expect(urls.count >= 1)
    #expect(urls[0].scheme == "x-apple.systempreferences")
    #expect(urls[0].absoluteString.contains("Privacy_Calendars"))
}

@Test func privacySettingsURL_reminders_opensPrivacyRemindersPane() {
    let urls = PrivacySettingsURL.macOSCandidates(for: .reminders)

    #expect(urls.count >= 1)
    #expect(urls[0].scheme == "x-apple.systempreferences")
    #expect(urls[0].absoluteString.contains("Privacy_Reminders"))
}

@Test func privacySettingsURL_notifications_prefersAppSpecificPane() {
    let bundleIdentifier = "de.reisen.Reisen"
    let urls = PrivacySettingsURL.macOSCandidates(
        for: .notifications,
        bundleIdentifier: bundleIdentifier
    )

    #expect(urls.count >= 2)
    #expect(urls[0].absoluteString.contains("Notifications-Settings.extension"))
    #expect(urls[0].absoluteString.contains("id=\(bundleIdentifier)"))
    #expect(urls[1].absoluteString.contains("Notifications-Settings.extension"))
}

@Test func privacyAccessDenial_readsPaneFromConformingError() {
    struct Denied: Error, PrivacyAccessDenying {
        var privacySettingPane: PrivacySettingPane? { .calendars }
    }

    #expect(PrivacyAccessDenial.pane(from: Denied()) == .calendars)
}

@Test func privacyAccessDenial_ignoresUnrelatedErrors() {
    struct Other: Error {}

    #expect(PrivacyAccessDenial.pane(from: Other()) == nil)
}

@Test func privacySettingPane_denialMessages_nameThePane() {
    #expect(PrivacySettingPane.calendars.denialMessage.contains("Kalenderzugriff"))
    #expect(PrivacySettingPane.calendars.denialMessage.contains("Kalender"))
    #expect(PrivacySettingPane.reminders.denialMessage.contains("Erinnerungen"))
    #expect(PrivacySettingPane.notifications.denialMessage.contains("Mitteilungen"))
}

@Test func privacySettingPane_openButtonTitle_isStable() {
    #expect(PrivacySettingPane.calendars.openButtonTitle == "Einstellungen öffnen")
    #expect(PrivacySettingPane.reminders.openButtonTitle == "Einstellungen öffnen")
    #expect(PrivacySettingPane.notifications.openButtonTitle == "Einstellungen öffnen")
}

@Test func privacySettingPane_restrictedCapabilityLabels_areStable() {
    #expect(PrivacySettingPane.calendars.restrictedCapabilityLabel == "Kalender")
    #expect(PrivacySettingPane.reminders.restrictedCapabilityLabel == "Erinnerungen")
    #expect(PrivacySettingPane.notifications.restrictedCapabilityLabel == "Mitteilungen")
}
