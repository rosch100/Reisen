import Foundation
import Testing
import ReisenDomain
@testable import ReisenAppCore

@Test @MainActor func pasteImportFailedFeatureRequestFlow_offerWithoutConfirmMakesNoHTTP() async {
    let client = MockGitHubIssues()
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    #expect(flow.phase == .confirming)
    #expect(client.createCount == 0)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_confirmWithoutOfferMakesNoHTTP() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let flow = PasteImportFailedFeatureRequestFlow()
    await flow.confirm(
        source: .text("Hallo"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 0)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_confirmAfterOfferCreatesIssue() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    await flow.confirm(
        source: .text("Hallo"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
    #expect(flow.phase == .succeeded(URL(string: "https://github.com/rosch100/Reisen/issues/1")!))
    #expect(!flow.canOffer)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_cancelOfferBlocksConfirm() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    flow.cancelOffer()
    #expect(flow.phase == .offering)
    await flow.confirm(
        source: .text("Hallo"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 0)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_submitFailureKeepsOffer() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { throw GitHubIssueTokenError.notEmbedded },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    await flow.confirm(
        source: .text("Hallo"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 0)
    #expect(flow.canOffer)
    #expect(flow.phase == .submitFailed("Issue-Token nicht eingebettet"))
    flow.acknowledgeSubmitFailure()
    #expect(flow.phase == .offering)
}
