import Foundation
import ReisenDomain

enum GitHubIssueAutoReport {
    static func isAutomaticReportingEnabled(defaults: UserDefaults = .standard) -> Bool {
        AppSettingsKeys.isReportErrorsToGitHub(defaults: defaults) && GitHubIssueToken.isEmbedded
    }

    static func shouldReport(error: Error) -> Bool {
        let mapped = UserNotificationAuthorization.mapped(error)
        if PrivacyAccessDenial.pane(from: mapped) != nil {
            return false
        }
        return shouldReport(message: mapped.localizedDescription)
    }

    static func shouldReport(message: String) -> Bool {
        !isExpectedUserState(message)
    }

    private static let expectedMessageFragments: [[String]] = [
        ["ist deaktiviert"],
        ["keine angemeldeten provider"],
        ["bitte", "anmelden"],
        ["zugriff wurde verweigert"],
        ["benachrichtigungen wurden nicht autorisiert"],
        ["notifications are not allowed"],
    ]

    private static func isExpectedUserState(_ message: String) -> Bool {
        let text = message.lowercased()
        return expectedMessageFragments.contains { fragments in
            fragments.allSatisfy { text.contains($0) }
        }
    }
}
