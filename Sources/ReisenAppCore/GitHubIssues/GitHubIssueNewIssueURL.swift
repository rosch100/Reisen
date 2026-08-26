import Foundation
import ReisenDomain

public enum GitHubIssueNewIssueURL {
    /// Sicheres Limit für den `body`-Query-Parameter (Browser/GitHub-URL-Länge).
    public static let maxBodyCharacterCount = 6_000
    /// Obergrenze für die encodierte Gesamt-URL inkl. Query.
    public static let maxURLLength = 8_000
    public static let composeFailureMessage = "Issue-URL konnte nicht erstellt werden."

    private static let truncationSuffix = """

    … (Text gekürzt — vollständige Meldung steht in der App.)
    """

    public static func compose(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID? = nil
    ) -> URL? {
        let trimmedTitle = String(SecretRedactor.redact(title).prefix(240))
        let body = bodyForQuery(
            kind: kind,
            title: trimmedTitle,
            message: message,
            providerID: providerID
        )
        return issueURL(title: trimmedTitle, body: body)
    }

    static func bodyForQuery(
        kind: GitHubIssueKind,
        title: String,
        message: String,
        providerID: ProviderID?
    ) -> String {
        let fullBody = GitHubIssueDiagnostic.collectedBody(
            kind: kind,
            title: title,
            message: message,
            providerID: providerID
        )
        var maxChars = maxBodyCharacterCount
        var body = truncated(fullBody, maxCharacters: maxChars)
        while !fitsInIssueURL(title: title, body: body), maxChars > 200 {
            maxChars -= 500
            body = truncated(fullBody, maxCharacters: maxChars)
        }
        return body
    }

    static func truncated(_ body: String, maxCharacters: Int) -> String {
        guard body.count > maxCharacters else { return body }
        let keep = max(0, maxCharacters - truncationSuffix.count)
        return String(body.prefix(keep)) + truncationSuffix
    }

    static func fitsInIssueURL(title: String, body: String) -> Bool {
        guard let url = issueURL(title: title, body: body) else { return false }
        return url.absoluteString.count <= maxURLLength
    }

    private static func issueURL(title: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = GitHubRepository.newIssuePath
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
