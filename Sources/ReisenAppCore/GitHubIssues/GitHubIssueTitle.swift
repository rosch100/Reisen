import Foundation

public enum GitHubIssueTitle {
    public static let storeLoadFailure = "Reisen-Fehler: Datenbank konnte nicht geladen werden"
    public static let uncaughtException = "Reisen: uncaught exception"

    public static func syncErrorReport(message: String) -> String {
        "Reisen-Fehler: \(summary(from: message))"
    }

    public static func feedbackReport(message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Reisen-Feedback: \(String(trimmed.prefix(80)))"
    }

    public static func summary(from message: String) -> String {
        let first = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? message
        return String(first.prefix(80))
    }
}
