import Testing
import Foundation
import UserNotifications
import ReisenDomain
@testable import ReisenAppCore

@Test func privacyOptionalCapability_skipsNotificationCalendarAndReminderDenials() {
    #expect(
        PrivacyOptionalCapability.deniedPane(
            from: LocalReminderScheduler.SchedulerError.authorizationDenied
        ) == .notifications
    )
    #expect(
        PrivacyOptionalCapability.deniedPane(from: notificationsNotAllowedError())
            == .notifications
    )
    #expect(
        PrivacyOptionalCapability.deniedPane(
            from: LocalEventKitBridge.EventKitError.accessDenied
        ) == .calendars
    )
    #expect(
        PrivacyOptionalCapability.deniedPane(
            from: LocalEventKitBridge.EventKitError.reminderAccessDenied
        ) == .reminders
    )
}

@Test func privacyOptionalCapability_doesNotSkipRealSideEffectFailures() {
    #expect(
        PrivacyOptionalCapability.deniedPane(
            from: LocalReminderScheduler.SchedulerError.notRunningAsAppBundle
        ) == nil
    )
    #expect(
        PrivacyOptionalCapability.deniedPane(
            from: LocalEventKitBridge.EventKitError.calendarWriteFailed
        ) == nil
    )
}

@Test func privacyOptionalCapability_statusHintNamesSkippedCapabilities() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }

    #expect(PrivacyOptionalCapability.statusHint(skipped: []) == nil)
    #expect(
        PrivacyOptionalCapability.statusHint(skipped: [.notifications])
            == L10n.format(.privacyContinuedWithout, L10n.string(.privacyNotifications))
    )
    #expect(
        PrivacyOptionalCapability.statusHint(skipped: [.calendars, .reminders])
            == L10n.format(
                .privacyContinuedWithout,
                [L10n.string(.privacyCalendars), L10n.string(.privacyReminders)].joined(separator: ", ")
            )
    )
}

@Test func privacyOptionalCapability_runSkipsDenialAndRethrowsOtherErrors() async throws {
    let skipped = try await PrivacyOptionalCapability.run {
        throw LocalEventKitBridge.EventKitError.accessDenied
    }
    #expect(skipped == .calendars)

    let succeeded = try await PrivacyOptionalCapability.run {}
    #expect(succeeded == nil)

    await #expect(throws: LocalEventKitBridge.EventKitError.calendarWriteFailed) {
        try await PrivacyOptionalCapability.run {
            throw LocalEventKitBridge.EventKitError.calendarWriteFailed
        }
    }
}

private func notificationsNotAllowedError() -> Error {
    NSError(
        domain: UNErrorDomain,
        code: UNError.Code.notificationsNotAllowed.rawValue,
        userInfo: [
            NSLocalizedDescriptionKey: "Notifications are not allowed for this application"
        ]
    )
}
