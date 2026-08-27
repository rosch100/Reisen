import Foundation

public enum GitHubIssueTitle {
    public static let storeLoadFailure = "[Fehler] Datenbank konnte nicht geladen werden"
    public static let uncaughtException = "[Fehler] Unbehandelte Ausnahme"

    /// SSOT für Issue-Titel aus Art und Nutzertext.
    public static func reportTitle(kind: GitHubIssueKind, message: String) -> String {
        "\(kind.titlePrefix) \(summary(from: message))"
    }

    public static func syncErrorReport(message: String) -> String {
        reportTitle(kind: .error, message: message)
    }

    public static func feedbackReport(message: String) -> String {
        reportTitle(kind: .feedback, message: message)
    }

    public static func summary(from message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        return String(first.prefix(80))
    }
}
