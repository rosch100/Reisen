import Foundation
import ReisenDomain

public enum GitHubIssueNewIssueURL {
    /// Sicheres Limit für den Formularfeld-Query-Parameter (Browser/GitHub-URL-Länge).
    public static let maxBodyCharacterCount = 6_000
    /// Obergrenze für die encodierte Gesamt-URL inkl. Query.
    public static let maxURLLength = 8_000
    public static let composeFailureMessage = "Issue-URL konnte nicht erstellt werden."

    private static let truncationSuffix = """

    … (Text gekürzt — vollständige Meldung steht in der App.)
    """

    public static func compose(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID? = nil,
        githubUsername: String? = nil,
        titleOverride: String? = nil
    ) -> URL? {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }
        let title = String(
            SecretRedactor.redact(
                titleOverride ?? GitHubIssueTitle.reportTitle(kind: kind, message: trimmedMessage)
            ).prefix(240)
        )
        let origin: GitHubIssueReportOrigin = .userGitHub(
            username: GitHubIssueReportOrigin.optionalNormalizedUsername(githubUsername)
        )
        let formFieldValue = formFieldValueForQuery(
            kind: kind,
            title: title,
            message: trimmedMessage,
            providerID: providerID,
            origin: origin
        )
        return issueURL(kind: kind, title: title, formFieldValue: formFieldValue)
    }

    static func formFieldValueForQuery(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID?,
        origin: GitHubIssueReportOrigin
    ) -> String {
        let fullValue = GitHubIssueDiagnostic.collectedFormFieldContent(
            kind: kind,
            message: message,
            providerID: providerID,
            origin: origin
        )
        var maxChars = maxBodyCharacterCount
        var value = truncated(fullValue, maxCharacters: maxChars)
        while !fitsInIssueURL(kind: kind, title: title, formFieldValue: value), maxChars > 200 {
            maxChars -= 500
            value = truncated(fullValue, maxCharacters: maxChars)
        }
        return value
    }

    static func truncated(_ body: String, maxCharacters: Int) -> String {
        guard body.count > maxCharacters else { return body }
        let keep = max(0, maxCharacters - truncationSuffix.count)
        return String(body.prefix(keep)) + truncationSuffix
    }

    static func fitsInIssueURL(kind: GitHubIssueKind, title: String, formFieldValue: String) -> Bool {
        guard let url = issueURL(kind: kind, title: title, formFieldValue: formFieldValue) else { return false }
        return url.absoluteString.count <= maxURLLength
    }

    private static func issueURL(kind: GitHubIssueKind, title: String, formFieldValue: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = GitHubRepository.newIssuePath
        components.queryItems = [
            URLQueryItem(name: "template", value: kind.issueTemplateFileName),
            URLQueryItem(name: "labels", value: kind.githubLabels.joined(separator: ",")),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: kind.issueFormFieldID, value: formFieldValue),
        ]
        return components.url
    }
}
