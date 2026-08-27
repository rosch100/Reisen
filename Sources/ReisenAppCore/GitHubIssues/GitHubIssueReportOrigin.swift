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
        switch self {
        case .embeddedToken(let name), .userGitHub(let name):
            name.map { "@\($0)" } ?? "—"
        }
    }
}
