import Testing
import Foundation
import UserNotifications
import ReisenDomain
@testable import ReisenAppCore

@Test func userNotificationAuthorization_mapsUNErrorNotAllowedToAuthorizationDenied() {
    let mapped = UserNotificationAuthorization.mapped(notificationsNotAllowedError())

    #expect(mapped is LocalReminderScheduler.SchedulerError)
    #expect(PrivacyAccessDenial.pane(from: mapped) == .notifications)
    #expect(
        mapped.localizedDescription == PrivacySettingPane.notifications.denialMessage
    )
}

@Test func userNotificationAuthorization_leavesUnrelatedErrorsUnchanged() {
    let original = NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorTimedOut,
        userInfo: [NSLocalizedDescriptionKey: "timeout"]
    )

    let mapped = UserNotificationAuthorization.mapped(original)
    let nsError = mapped as NSError
    #expect(nsError.domain == NSURLErrorDomain)
    #expect(nsError.code == NSURLErrorTimedOut)
}

@Test func userNotificationAuthorization_usableStatusesAllowScheduling() {
    #expect(UserNotificationAuthorization.isUsable(.authorized))
    #expect(UserNotificationAuthorization.isUsable(.provisional))
    #if os(iOS)
    #expect(UserNotificationAuthorization.isUsable(.ephemeral))
    #endif
    #expect(!UserNotificationAuthorization.isUsable(.denied))
    #expect(!UserNotificationAuthorization.isUsable(.notDetermined))
}

@Test func githubIssueAutoReport_skipsSystemNotificationsNotAllowed() {
    #expect(!GitHubIssueAutoReport.shouldReport(error: notificationsNotAllowedError()))
    #expect(
        !GitHubIssueAutoReport.shouldReport(
            message: "Notifications are not allowed for this application"
        )
    )
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
