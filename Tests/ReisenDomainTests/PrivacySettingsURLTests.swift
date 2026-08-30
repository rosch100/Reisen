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
    L10n.withLocale(Locale(identifier: "de")) {

    #if os(iOS)
    let privacyRootPath = L10n.format(.settingsPathPrivacy, L10n.string(.settingsAppIos))
    let notificationsPath = L10n.format(.settingsPathNotifications, L10n.string(.settingsAppIos))
    #else
    let privacyRootPath = L10n.format(.settingsPathPrivacy, L10n.string(.settingsAppMacos))
    let notificationsPath = L10n.format(.settingsPathNotifications, L10n.string(.settingsAppMacos))
    #endif

    #expect(PrivacySettingPane.calendars.denialMessage == L10n.format(.privacyDenialCalendars, privacyRootPath))
    #expect(PrivacySettingPane.reminders.denialMessage == L10n.format(.privacyDenialReminders, privacyRootPath))
    #expect(PrivacySettingPane.notifications.denialMessage == L10n.format(.privacyDenialNotifications, notificationsPath))
    }
}

@Test func privacySettingPane_openButtonTitle_isStable() {
    L10n.withLocale(Locale(identifier: "de")) {

    #expect(PrivacySettingPane.calendars.openButtonTitle == L10n.string(.privacyOpenSettings))
    #expect(PrivacySettingPane.reminders.openButtonTitle == L10n.string(.privacyOpenSettings))
    #expect(PrivacySettingPane.notifications.openButtonTitle == L10n.string(.privacyOpenSettings))
    }
}

@Test func privacySettingPane_restrictedCapabilityLabels_areStable() {
    L10n.withLocale(Locale(identifier: "de")) {

    #expect(PrivacySettingPane.calendars.restrictedCapabilityLabel == L10n.string(.privacyCalendars))
    #expect(PrivacySettingPane.reminders.restrictedCapabilityLabel == L10n.string(.privacyReminders))
    #expect(PrivacySettingPane.notifications.restrictedCapabilityLabel == L10n.string(.privacyNotifications))
    }
}
