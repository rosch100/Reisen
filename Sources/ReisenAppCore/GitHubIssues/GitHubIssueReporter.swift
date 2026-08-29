import Foundation
import Observation
import ReisenData
import ReisenDomain

public enum GitHubIssueReporterError: Error, Equatable, LocalizedError {
    case rateLimited
    case persistedStateCorrupt
    case attachmentTooLarge(maxBytes: Int)
    case attachmentEmpty

    public var errorDescription: String? {
        switch self {
        case .rateLimited:
            return "Zu viele neue GitHub-Issues in dieser Stunde"
        case .persistedStateCorrupt:
            return "Gespeicherter Issue-Reporter-Zustand ist ungültig"
        case .attachmentTooLarge(let maxBytes):
            return "Dokument ist größer als \(maxBytes) Bytes"
        case .attachmentEmpty:
            return "Dokumentanhang ist leer"
        }
    }
}

struct GitHubIssueReporterState: Codable, Equatable {
    var createTimestamps: [Date] = []
    var lastCommentAt: [String: Date] = [:]
    var openFingerprints: [String: Int] = [:]
}

@MainActor
@Observable
public final class GitHubIssueReporter {
    public static let shared = GitHubIssueReporter()

    public static var defaultPersistenceURL: URL? {
        PersistenceBootstrap.supportDirectoryURL()?
            .appendingPathComponent("github-issue-reporter-state.json")
    }

    public private(set) var lastPublicIssueURL: URL?
    public private(set) var lastReportErrorMessage: String?

    private let client: any GitHubIssueSubmitting
    private let tokenProvider: @Sendable () throws -> String
    private let now: @Sendable () -> Date
    private let maxCreatesPerHour: Int
    private let persistenceURL: URL?
    private var state = GitHubIssueReporterState()
    private var persistedStateCorrupt = false
    private static let hourlyWindow: TimeInterval = 3600

    public init(
        client: (any GitHubIssueSubmitting)? = nil,
        tokenProvider: @escaping @Sendable () throws -> String = { try GitHubIssueToken.value() },
        now: @escaping @Sendable () -> Date = { Date() },
        maxCreatesPerHour: Int = 10,
        persistenceURL: URL? = GitHubIssueReporter.defaultPersistenceURL
    ) {
        self.client = client ?? GitHubIssueAPIClient(tokenProvider: tokenProvider)
        self.tokenProvider = tokenProvider
        self.now = now
        self.maxCreatesPerHour = maxCreatesPerHour
        self.persistenceURL = persistenceURL
        switch Self.loadState(from: persistenceURL) {
        case .missing:
            self.state = GitHubIssueReporterState()
        case .loaded(let loaded):
            self.state = loaded
        case .corrupt:
            self.state = GitHubIssueReporterState()
            self.persistedStateCorrupt = true
        }
    }

    @discardableResult
    public func report(
        kind: GitHubIssueKind,
        message: String,
        providerID: ProviderID?,
        titleOverride: String? = nil,
        reporterGitHubUsername: String? = nil,
        attachments: [GitHubIssueAttachment] = [],
        fingerprintMessage: String? = nil
    ) async throws -> GitHubCreatedIssue {
        lastReportErrorMessage = nil
        if persistedStateCorrupt {
            lastReportErrorMessage = GitHubIssueReporterError.persistedStateCorrupt.localizedDescription
            throw GitHubIssueReporterError.persistedStateCorrupt
        }
        _ = try tokenProvider()

        let attachmentComments: [String]
        do {
            attachmentComments = try attachments.flatMap { try GitHubIssueAttachmentCodec.comments(for: $0) }
        } catch GitHubIssueAttachmentCodecError.empty {
            lastReportErrorMessage = GitHubIssueReporterError.attachmentEmpty.localizedDescription
            throw GitHubIssueReporterError.attachmentEmpty
        } catch GitHubIssueAttachmentCodecError.tooLarge(let maxBytes) {
            lastReportErrorMessage = GitHubIssueReporterError.attachmentTooLarge(maxBytes: maxBytes)
                .localizedDescription
            throw GitHubIssueReporterError.attachmentTooLarge(maxBytes: maxBytes)
        } catch {
            lastReportErrorMessage = error.localizedDescription
            throw error
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let redactedMessage = SecretRedactor.redact(trimmedMessage)
        let fingerprintSource = SecretRedactor.redact(
            (fingerprintMessage ?? trimmedMessage).trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let title = GitHubIssueTitle.reportTitle(kind: kind, message: trimmedMessage, override: titleOverride)
        let diagnostics = GitHubIssueDiagnostic.deviceSnapshot(kind: kind, redactedMessage: fingerprintSource)
        let fingerprint = diagnostics.fingerprint
        let body = GitHubIssueDiagnostic.body(
            kind: kind,
            title: title,
            message: trimmedMessage,
            providerID: providerID,
            origin: .embeddedToken(
                attributedUsername: GitHubUsername.optionalValid(reporterGitHubUsername)
            ),
            diagnostics: diagnostics
        )
        let labels = kind.githubLabels

        do {
            if let existing = try await resolveExistingIssue(fingerprint: fingerprint) {
                return rememberURL(
                    try await commentIfAllowed(
                        fingerprint: fingerprint,
                        issueNumber: existing,
                        body: commentBody(kind: kind, message: redactedMessage)
                    )
                )
            }

            try enforceCreateRateLimit()
            let created = try await client.createIssue(
                title: GitHubIssueTitle.githubAPITitle(title),
                body: body,
                labels: labels
            )
            state.createTimestamps.append(now())
            state.openFingerprints[fingerprint] = created.number
            persist()
            for comment in attachmentComments {
                _ = try await client.comment(issueNumber: created.number, body: comment)
            }
            return rememberURL(created)
        } catch {
            lastReportErrorMessage = error.localizedDescription
            throw error
        }
    }

    private func resolveExistingIssue(fingerprint: String) async throws -> Int? {
        if let local = state.openFingerprints[fingerprint] {
            return local
        }
        guard let remote = try await client.searchOpenFingerprint(fingerprint) else {
            return nil
        }
        state.openFingerprints[fingerprint] = remote
        persist()
        return remote
    }

    private func rememberURL(_ created: GitHubCreatedIssue) -> GitHubCreatedIssue {
        lastPublicIssueURL = created.htmlURL
        return created
    }

    private func commentIfAllowed(
        fingerprint: String,
        issueNumber: Int,
        body: String
    ) async throws -> GitHubCreatedIssue {
        let timestamp = now()
        if let previous = state.lastCommentAt[fingerprint], timestamp.timeIntervalSince(previous) < Self.hourlyWindow {
            return GitHubCreatedIssue(
                number: issueNumber,
                htmlURL: GitHubRepository.issueURL(number: issueNumber),
                didPostUpdate: false
            )
        }
        let created = try await client.comment(issueNumber: issueNumber, body: body)
        state.lastCommentAt[fingerprint] = timestamp
        persist()
        return created
    }

    private func commentBody(kind: GitHubIssueKind, message: String) -> String {
        """
        Erneuter \(kind.repeatReportLabel) (\(ISO8601DateFormatter().string(from: now()))):

        ```
        \(message)
        ```
        """
    }

    private func enforceCreateRateLimit() throws {
        let timestamp = now()
        let windowStart = timestamp.addingTimeInterval(-Self.hourlyWindow)
        state.createTimestamps.removeAll { $0 < windowStart }
        guard state.createTimestamps.count < maxCreatesPerHour else {
            throw GitHubIssueReporterError.rateLimited
        }
    }

    private func persist() {
        guard !persistedStateCorrupt, let persistenceURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: persistenceURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("[Reisen] GitHub-Issue-Reporter-State nicht gespeichert: \(error.localizedDescription)")
            #endif
        }
    }

    private enum PersistenceLoad {
        case missing
        case loaded(GitHubIssueReporterState)
        case corrupt
    }

    private static func loadState(from url: URL?) -> PersistenceLoad {
        guard let url else { return .missing }
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .corrupt }
        guard let decoded = try? JSONDecoder().decode(GitHubIssueReporterState.self, from: data) else {
            return .corrupt
        }
        return .loaded(decoded)
    }
}
