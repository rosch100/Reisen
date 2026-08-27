import Foundation

/// Entscheidet, ob ein Issue per eingebettetem Token oder im Browser mit eigenem GitHub-Konto gemeldet wird.
public enum GitHubIssueSubmissionMode: Equatable, Sendable {
    case embeddedToken
    case openInGitHub

    public static func resolve(tokenEmbedded: Bool) -> GitHubIssueSubmissionMode {
        tokenEmbedded ? .embeddedToken : .openInGitHub
    }
}
