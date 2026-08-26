import Foundation
import ReisenDomain

enum GitHubIssueAutoReport {
    static func isAutomaticReportingEnabled(defaults: UserDefaults = .standard) -> Bool {
        AppSettingsKeys.isReportErrorsToGitHub(defaults: defaults) && GitHubIssueToken.isEmbedded
    }

    static func shouldReport(error: Error) -> Bool {
        if PrivacyAccessDenial.pane(from: error) != nil {
            return false
        }
        return shouldReport(message: error.localizedDescription)
    }

    static func shouldReport(message: String) -> Bool {
        !isExpectedUserState(message)
    }

    private static func isExpectedUserState(_ message: String) -> Bool {
        let text = message.lowercased()
        if text.contains("ist deaktiviert") { return true }
        if text.contains("keine angemeldeten provider") { return true }
        if text.contains("bitte") && text.contains("anmelden") { return true }
        if text.contains("zugriff wurde verweigert") { return true }
        if text.contains("benachrichtigungen wurden nicht autorisiert") { return true }
        return false
    }
}
