import Foundation
import ReisenDomain

public enum GitHubIssueKind: String, Sendable {
    case error
    case feedback

    /// Anzeige in der Diagnose-Tabelle (deutsch, konsistent mit Issue-Templates).
    public var displayName: String {
        switch self {
        case .error:
            "Fehler"
        case .feedback:
            "Feedback"
        }
    }

    /// Präfix im Issue-Titel (SSOT mit `.github/ISSUE_TEMPLATE/*.yml`).
    public var titlePrefix: String { "[\(displayName)]" }

    /// Bezeichnung für erneute Meldungen als Kommentar.
    public var repeatReportLabel: String {
        switch self {
        case .error:
            "Fehlerbericht"
        case .feedback:
            displayName
        }
    }

    /// Entspricht dem Label `source/in-app`.
    public var sourceLabel: String { "In-App" }

    /// `.github/ISSUE_TEMPLATE/…` und Feld-`id` für vorausgefüllte „New issue“-URLs.
    public struct IssueForm: Equatable, Sendable {
        public let templateFileName: String
        public let fieldID: String
    }

    public var issueForm: IssueForm {
        switch self {
        case .error:
            IssueForm(templateFileName: "bug.yml", fieldID: "what")
        case .feedback:
            IssueForm(templateFileName: "feedback.yml", fieldID: "feedback")
        }
    }

    public var githubLabels: [String] {
        ["kind/\(rawValue)", "source/\(sourceLabel.lowercased())"]
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
