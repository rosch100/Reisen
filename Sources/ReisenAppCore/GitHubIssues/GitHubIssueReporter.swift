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
            if let localNumber = state.openFingerprints[fingerprint] {
                return rememberURL(
                    try await commentIfAllowed(
                        fingerprint: fingerprint,
                        issueNumber: localNumber,
                        body: commentBody(kind: kind, message: redactedMessage)
                    )
                )
            }

            if let remoteNumber = try await client.searchOpenFingerprint(fingerprint) {
                return rememberURL(
                    try await completeExistingIssue(
                        fingerprint: fingerprint,
                        issueNumber: remoteNumber,
                        attachmentComments: attachmentComments,
                        repeatComment: commentBody(kind: kind, message: redactedMessage)
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
            try await postAttachmentComments(issueNumber: created.number, comments: attachmentComments)
            rememberOpenFingerprint(fingerprint, issueNumber: created.number)
            return rememberURL(created)
        } catch {
            lastReportErrorMessage = error.localizedDescription
            throw error
        }
    }

    private func completeExistingIssue(
        fingerprint: String,
        issueNumber: Int,
        attachmentComments: [String],
        repeatComment: String
    ) async throws -> GitHubCreatedIssue {
        if attachmentComments.isEmpty {
            rememberOpenFingerprint(fingerprint, issueNumber: issueNumber)
            return try await commentIfAllowed(
                fingerprint: fingerprint,
                issueNumber: issueNumber,
                body: repeatComment
            )
        }
        try await postAttachmentComments(issueNumber: issueNumber, comments: attachmentComments)
        rememberOpenFingerprint(fingerprint, issueNumber: issueNumber)
        return GitHubCreatedIssue(
            number: issueNumber,
            htmlURL: GitHubRepository.issueURL(number: issueNumber)
        )
    }

    private func postAttachmentComments(issueNumber: Int, comments: [String]) async throws {
        for comment in comments {
            _ = try await client.comment(issueNumber: issueNumber, body: comment)
        }
    }

    private func rememberOpenFingerprint(_ fingerprint: String, issueNumber: Int) {
        state.openFingerprints[fingerprint] = issueNumber
        persist()
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
        let env = RuntimeEnvironmentSnapshot.live()
        let log = SyncLog.recentTail()
        let logBlock: String
        switch log {
        case .attached(let preview, _, _, _, _), .compressionFailed(let preview):
            let lines = DiagnosticLogCompressor.preview(
                from: preview,
                lastLineCount: DiagnosticLogAttachment.commentPreviewLineCount
            )
            logBlock = "```\n\(lines)\n```"
        case .missing:
            logBlock = "Sync-Log: nicht vorhanden"
        case .empty:
            logBlock = "Sync-Log: leer"
        case .unreadable(let detail):
            logBlock = "Sync-Log: nicht lesbar\n\(SecretRedactor.redact(detail))"
        }
        return """
        Erneuter \(kind.repeatReportLabel) (\(ISO8601DateFormatter().string(from: now()))):

        ```
        \(message)
        ```

        | RAM physisch | \(RuntimeEnvironmentSnapshot.mebibytes(env.physicalMemoryBytes)) |
        | Thermal | \(env.thermalState) |
        | Energiesparmodus | \(env.lowPowerMode ? "ja" : "nein") |
        | Freier Volume-Platz | \(RuntimeEnvironmentSnapshot.optionalGibibytes(env.volumeAvailableBytes)) |
        | iCloud | \(env.cloudKitEnabled ? "an" : "aus") |

        \(logBlock)
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
