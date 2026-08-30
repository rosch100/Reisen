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
    #expect(created.body.contains(GitHubRepository.issueAttachmentPolicyCell))
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

@Test func pasteImportFailedMailDraft_rfc822ContainsMarkerHeadersAndAttachmentBytes() throws {
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34])
    let issueURL = URL(string: "https://github.com/rosch100/Reisen/issues/42")!
    let draft = PasteImportFailedMailDraft.make(source: .pdf(pdf), issueURL: issueURL)
    let rfc822 = draft.rfc822Data()
    let text = try #require(String(data: rfc822, encoding: .utf8))
    #expect(text.contains("To: \(GitHubRepository.feedbackEmail)"))
    #expect(text.contains("Subject:"))
    #expect(text.contains(PasteImportFailedMailDraft.skipIngressMarker))
    #expect(text.hasPrefix("To:"))
    // Erste nichtleere Zeile des Textteils — SSOT mit Gmail-Ingress.
    let plainPart = try #require(
        text.components(separatedBy: "Content-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\n").last
    )
    let plainBody = plainPart.components(separatedBy: "\r\n--").first ?? ""
    let firstNonEmpty = plainBody
        .split(separator: "\r\n", omittingEmptySubsequences: true)
        .first
        .map(String.init)
    #expect(firstNonEmpty == PasteImportFailedMailDraft.skipIngressMarker)
    #expect(text.contains("Content-Disposition: attachment"))
    #expect(text.contains("paste.pdf"))
    #expect(text.contains("application/pdf"))
    let decoded = try #require(
        Data(base64Encoded: PasteImportFailedMailDraftRFC822Helpers.base64Payload(in: text))
    )
    #expect(decoded == pdf)
}

@Test func pasteImportFailedMailDraft_rfc822ImageUsesDetectedMime() {
    let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01])
    let draft = PasteImportFailedMailDraft.make(source: .image(png), issueURL: nil)
    let text = String(decoding: draft.rfc822Data(), as: UTF8.self)
    #expect(text.contains("image/png"))
    #expect(text.contains("paste-image.png"))
    #expect(draft.mimeType == "image/png")
}

@Test func pasteImportFailedMailDraft_rfc822SanitizesFilenameHeaderInjection() {
    let draft = PasteImportFailedMailDraft(
        to: GitHubRepository.feedbackEmail,
        subject: "Test",
        body: PasteImportFailedMailDraft.skipIngressMarker,
        fileName: "evil.pdf\r\nX-Injected: yes",
        mimeType: "application/pdf\r\nX-Bad: 1",
        data: Data([0x25, 0x50, 0x44, 0x46])
    )
    let text = String(decoding: draft.rfc822Data(), as: UTF8.self)
    #expect(!text.contains("\r\nX-Injected:"))
    #expect(!text.contains("\r\nX-Bad:"))
    #expect(text.contains("application/octet-stream") || text.contains("application/pdf"))
    #expect(PasteImportFailedMailDraft.mimeSafeFileName("evil.pdf\r\nX-Injected: yes") == "evil.pdfX-Injected: yes")
    #expect(PasteImportFailedMailDraft.mimeSafeType("application/pdf\r\nX-Bad: 1") == "application/octet-stream")
}

private enum PasteImportFailedMailDraftRFC822Helpers {
    static func base64Payload(in rfc822: String) -> String {
        let marker = "Content-Transfer-Encoding: base64\r\nContent-Disposition:"
        guard let range = rfc822.range(of: marker) else { return "" }
        let afterHeaders = rfc822[range.upperBound...]
        guard let blank = afterHeaders.range(of: "\r\n\r\n") else { return "" }
        let payload = afterHeaders[blank.upperBound...]
        let end = payload.range(of: "\r\n--")?.lowerBound ?? payload.endIndex
        return String(payload[..<end])
            .replacingOccurrences(of: "\r\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
