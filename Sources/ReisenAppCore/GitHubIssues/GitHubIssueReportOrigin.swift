import Foundation
import ReisenDomain

/// Wie das Issue erstellt wird (Token-API vs. GitHub-Konto des Nutzers).
public enum GitHubIssueReportOrigin: Sendable, Equatable {
    case embeddedToken
    case userGitHub(username: String)

    public var meldewegLabel: String {
        switch self {
        case .embeddedToken:
            "App-Token"
        case .userGitHub:
            "GitHub-Konto"
        }
    }

    public var githubUserLabel: String {
        switch self {
        case .embeddedToken:
            "—"
        case .userGitHub(let username):
            "@\(username)"
        }
    }

    public static func from(githubUsername: String?) -> GitHubIssueReportOrigin {
        guard let username = githubUsername else { return .embeddedToken }
        let normalized = GitHubUsername.normalized(username)
        guard !normalized.isEmpty else { return .embeddedToken }
        return .userGitHub(username: normalized)
    }
}
