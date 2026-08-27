import Foundation
import ReisenDomain

/// Meldeweg (Token-API vs. GitHub-Konto) und optionale GitHub-Zuordnung im Issue-Text.
public enum GitHubIssueReportOrigin: Sendable, Equatable {
    case embeddedToken(attributedUsername: String?)
    case userGitHub(username: String?)

    public var meldewegLabel: String {
        switch self {
        case .embeddedToken:
            "App-Token"
        case .userGitHub:
            "GitHub-Konto"
        }
    }

    public var githubUserLabel: String {
        let username: String?
        switch self {
        case .embeddedToken(let attributedUsername):
            username = attributedUsername
        case .userGitHub(let name):
            username = name
        }
        guard let username else { return "—" }
        return "@\(username)"
    }

    public static func optionalNormalizedUsername(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = GitHubUsername.normalized(raw)
        return normalized.isEmpty ? nil : normalized
    }
}
