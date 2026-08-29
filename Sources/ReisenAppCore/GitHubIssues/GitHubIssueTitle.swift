import Foundation
import ReisenDomain

public enum GitHubIssueTitle {
    public static let githubAPIMaxLength = GitHubRepository.issueTitleMaxLength
    public static let maxSummaryLength = GitHubRepository.issueTitleSummaryMaxLength

    public static var storeLoadFailure: String {
        reportTitle(kind: .error, message: "Datenbank konnte nicht geladen werden")
    }

    public static var uncaughtException: String {
        reportTitle(kind: .error, message: "Unbehandelte Ausnahme")
    }

    /// SSOT für Issue-Titel aus Art, Nutzertext und optionalem Override.
    public static func reportTitle(kind: GitHubIssueKind, message: String, override: String? = nil) -> String {
        override ?? "\(kind.titlePrefix) \(summary(from: message))"
    }

    /// Redigierter Titel für GitHub-API und New-Issue-URLs.
    public static func githubAPITitle(_ title: String) -> String {
        String(SecretRedactor.redact(title).prefix(githubAPIMaxLength))
    }

    public static func summary(from message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        return String(first.prefix(maxSummaryLength))
    }
}
