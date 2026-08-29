import Foundation
import ReisenDomain

public enum GitHubIssueNewIssueURL {
    /// Sicheres Limit für den Formularfeld-Query-Parameter (Browser/GitHub-URL-Länge).
    public static let maxBodyCharacterCount = 6_000
    /// Obergrenze für die encodierte Gesamt-URL inkl. Query.
    public static let maxURLLength = 8_000
    public static let composeFailureMessage = "Issue-URL konnte nicht erstellt werden."
    static let minTruncatedBodyCharacters = 200
    static let bodyTruncationStep = 500

    public static func compose(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID? = nil,
        githubUsername: String? = nil,
        titleOverride: String? = nil
    ) -> URL? {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }
        let title = GitHubIssueTitle.githubAPITitle(
            GitHubIssueTitle.reportTitle(kind: kind, message: trimmedMessage, override: titleOverride)
        )
        let origin: GitHubIssueReportOrigin = .userGitHub(
            username: GitHubUsername.optionalValid(githubUsername)
        )
        let formFieldValue = formFieldValueForQuery(
            kind: kind,
            title: title,
            message: trimmedMessage,
            providerID: providerID,
            origin: origin
        )
        return issueURLIfFits(kind: kind, title: title, formFieldValue: formFieldValue)
    }

    static func formFieldValueForQuery(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin
    ) -> String {
        let snapshot = GitHubIssueDiagnostic.deviceSnapshot(
            kind: kind,
            redactedMessage: SecretRedactor.redact(message)
        )
        return GitHubIssueDiagnostic.collectedFormFieldContent(
            kind: kind,
            message: message,
            providerID: providerID,
            origin: origin,
            diagnostics: snapshot,
            shrinkingWhile: { value in
                !fitsInIssueURL(kind: kind, title: title, formFieldValue: value)
                    || value.count > maxBodyCharacterCount
            },
            minimumFencedCharacters: minTruncatedBodyCharacters,
            step: bodyTruncationStep
        )
    }

    static func fitsInIssueURL(kind: GitHubIssueKind, title: String, formFieldValue: String) -> Bool {
        issueURLIfFits(kind: kind, title: title, formFieldValue: formFieldValue) != nil
    }

    static func issueURLIfFits(kind: GitHubIssueKind, title: String, formFieldValue: String) -> URL? {
        guard let url = issueURL(kind: kind, title: title, formFieldValue: formFieldValue),
              url.absoluteString.count <= maxURLLength
        else {
            return nil
        }
        return url
    }

    private static func issueURL(kind: GitHubIssueKind, title: String, formFieldValue: String) -> URL? {
        let form = kind.issueForm
        return GitHubRepository.newIssueURL(queryItems: [
            URLQueryItem(name: "template", value: form.templateFileName),
            URLQueryItem(name: "labels", value: kind.githubLabels.joined(separator: ",")),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: form.fieldID, value: formFieldValue),
        ])
    }
}
