import Foundation
import Testing
import ReisenDomain
@testable import ReisenAppCore

@Test @MainActor func pasteImportFailedFeatureRequest_textCreatesFeatureWithoutDocumentOrComments() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let outcome = try await PasteImportFailedFeatureRequest.submit(
        source: .text("PNR ABC"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    let created = try #require(client.lastCreate)
    #expect(created.labels.contains("kind/feature"))
    #expect(created.title.hasPrefix("[Feature]"))
    #expect(created.body.contains("noCandidates"))
    #expect(created.body.contains("Quelle: text"))
    #expect(!created.body.contains("PNR ABC"))
    #expect(created.body.contains("per E-Mail"))
    #expect(!created.body.contains(GitHubRepository.feedbackEmail))
    #expect(client.commentCount == 0)
    #expect(outcome.mail.to == GitHubRepository.feedbackEmail)
    #expect(outcome.mail.data == Data("PNR ABC".utf8))
    #expect(outcome.mail.fileName == "paste.txt")
    #expect(outcome.mail.body.contains(PasteImportFailedMailDraft.skipIngressMarker))
}

@Test @MainActor func pasteImportFailedFeatureRequest_pdfLeavesGitHubWithoutAttachmentComments() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
    let outcome = try await PasteImportFailedFeatureRequest.submit(
        source: .pdf(pdf),
        reason: .model,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
    #expect(client.commentCount == 0)
    #expect(client.lastCreate?.labels.contains("kind/feature") == true)
    #expect(client.lastCreate?.body.contains("model") == true)
    #expect(outcome.mail.data == pdf)
    #expect(outcome.mail.fileName == "paste.pdf")
    #expect(outcome.mail.mimeType == "application/pdf")
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

@Test @MainActor func pasteImportFailedFeatureRequest_longTextStillCreatesMetadataIssue() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let oversized = String(repeating: "a", count: GitHubIssueAttachmentCodec.maxSourceBytes + 1)
    let outcome = try await PasteImportFailedFeatureRequest.submit(
        source: .text(oversized),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
    #expect(!(client.lastCreate?.body.contains(oversized) ?? true))
    #expect(outcome.mail.data.count == oversized.utf8.count)
}
