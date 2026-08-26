import Foundation
import ReisenDomain

public enum GitHubIssueKind: String, Sendable {
    case error
    case feedback

    public var githubLabels: [String] {
        switch self {
        case .error:
            ["kind/error"]
        case .feedback:
            ["kind/feedback"]
        }
    }
}

public struct GitHubCreatedIssue: Equatable, Sendable {
    public let number: Int
    public let htmlURL: URL
    /// `false`, wenn nur auf ein bestehendes Issue verwiesen wird (Kommentar-Throttle).
    public let didPostUpdate: Bool

    public init(number: Int, htmlURL: URL, didPostUpdate: Bool = true) {
        self.number = number
        self.htmlURL = htmlURL
        self.didPostUpdate = didPostUpdate
    }
}

public protocol GitHubIssueSubmitting: AnyObject, Sendable {
    func searchOpenFingerprint(_ fingerprint: String) async throws -> Int?
    func createIssue(title: String, body: String, labels: [String]) async throws -> GitHubCreatedIssue
    func comment(issueNumber: Int, body: String) async throws -> GitHubCreatedIssue
}
