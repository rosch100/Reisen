import Foundation
import Testing
@testable import ReisenAppCore

@Test func githubIssueAttachmentCodec_rejectsEmptyData() {
    let attachment = GitHubIssueAttachment(
        fileName: "a.bin",
        mimeType: "application/octet-stream",
        data: Data()
    )
    #expect(throws: GitHubIssueAttachmentCodecError.empty) {
        _ = try GitHubIssueAttachmentCodec.comments(for: attachment)
    }
}

@Test func githubIssueAttachmentCodec_splitsUnderBudget() throws {
    let data = Data(repeating: 0x41, count: 100)
    let comments = try GitHubIssueAttachmentCodec.comments(
        for: GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)
    )
    #expect(!comments.isEmpty)
    #expect(comments.allSatisfy { $0.contains(GitHubIssueAttachmentCodec.marker) })
    #expect(comments.allSatisfy { $0.count <= GitHubIssueAttachmentCodec.commentBodyBudget })
    #expect(comments.joined().contains("paste.pdf"))
}

@Test func githubIssueAttachmentCodec_rejectsOverMaxBytes() {
    let data = Data(repeating: 1, count: GitHubIssueAttachmentCodec.maxSourceBytes + 1)
    #expect(throws: GitHubIssueAttachmentCodecError.tooLarge(maxBytes: GitHubIssueAttachmentCodec.maxSourceBytes)) {
        _ = try GitHubIssueAttachmentCodec.comments(
            for: GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)
        )
    }
}

@Test @MainActor func githubIssueReporter_attachmentsPostCommentsAfterCreate() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let data = Data("pdf".utf8)
    _ = try await reporter.report(
        kind: .feature,
        message: "Paste-Import: Dokument nicht erkannt",
        providerID: nil,
        attachments: [GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)]
    )
    #expect(client.createCount == 1)
    #expect(client.commentCount >= 1)
}

@Test @MainActor func githubIssueReporter_tooLargeAttachmentCreatesNoIssue() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let data = Data(repeating: 1, count: GitHubIssueAttachmentCodec.maxSourceBytes + 1)
    await #expect(throws: GitHubIssueReporterError.attachmentTooLarge(maxBytes: GitHubIssueAttachmentCodec.maxSourceBytes)) {
        try await reporter.report(
            kind: .feature,
            message: "x",
            providerID: nil,
            attachments: [GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)]
        )
    }
    #expect(client.createCount == 0)
}

@Test @MainActor func githubIssueReporter_attachmentsWithoutTokenMakeNoHTTP() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { throw GitHubIssueTokenError.notEmbedded },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    await #expect(throws: GitHubIssueTokenError.notEmbedded) {
        try await reporter.report(
            kind: .feature,
            message: "x",
            providerID: nil,
            attachments: [GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: Data("pdf".utf8))]
        )
    }
    #expect(client.createCount == 0)
    #expect(client.commentCount == 0)
}
