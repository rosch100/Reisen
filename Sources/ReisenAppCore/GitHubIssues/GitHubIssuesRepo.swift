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
    public var titlePrefix: String {
        switch self {
        case .error:
            "[Fehler]"
        case .feedback:
            "[Feedback]"
        }
    }

    /// Bezeichnung für erneute Meldungen als Kommentar.
    public var repeatReportLabel: String {
        switch self {
        case .error:
            "Fehlerbericht"
        case .feedback:
            "Feedback"
        }
    }

    /// Entspricht dem Label `source/in-app`.
    public var sourceLabel: String { "In-App" }

    /// Überschrift für den Nutzertext im vollständigen Issue-Body (Token-API).
    public var messageSectionTitle: String {
        displayName
    }

    /// `.github/ISSUE_TEMPLATE/…` für vorausgefüllte „New issue“-URLs.
    public var issueTemplateFileName: String {
        switch self {
        case .error:
            "bug.yml"
        case .feedback:
            "feedback.yml"
        }
    }

    /// Feld-`id` im Issue-Formular (URL-Prefill).
    public var issueFormFieldID: String {
        switch self {
        case .error:
            "what"
        case .feedback:
            "feedback"
        }
    }

    public var githubLabels: [String] {
        switch self {
        case .error:
            ["kind/error", "source/in-app"]
        case .feedback:
            ["kind/feedback", "source/in-app"]
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
