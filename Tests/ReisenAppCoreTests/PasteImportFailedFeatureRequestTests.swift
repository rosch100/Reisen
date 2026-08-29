import Foundation
import Testing
import ReisenDomain
@testable import ReisenAppCore

@Test @MainActor func pasteImportFailedFeatureRequest_textCreatesFeatureWithoutAttachment() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .text("PNR ABC"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    let created = try #require(client.lastCreate)
    #expect(created.labels.contains("kind/feature"))
    #expect(created.title.hasPrefix("[Feature]"))
    #expect(created.body.contains("noCandidates") || created.body.contains("Keine Buchung"))
    #expect(client.commentCount == 0)
}

@Test @MainActor func pasteImportFailedFeatureRequest_pdfAttachesBinary() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .pdf(pdf),
        reason: .model,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
    #expect(client.commentCount >= 1)
    #expect(client.lastCreate?.labels.contains("kind/feature") == true)
}

@Test @MainActor func pasteImportFailedFeatureRequest_sameDocumentDifferentReasonReusesIssue() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .pdf(pdf),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .pdf(pdf),
        reason: .model,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
}

@Test @MainActor func pasteImportFailedFeatureRequest_oversizedTextDoesNotCreateIssue() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let oversized = String(repeating: "a", count: GitHubIssueAttachmentCodec.maxSourceBytes + 1)
    await #expect(throws: GitHubIssueReporterError.attachmentTooLarge(maxBytes: GitHubIssueAttachmentCodec.maxSourceBytes)) {
        try await PasteImportFailedFeatureRequest.submit(
            source: .text(oversized),
            reason: .noCandidates,
            reporter: reporter,
            reporterGitHubUsername: nil
        )
    }
    #expect(client.createCount == 0)
}
