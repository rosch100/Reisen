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

@Test @MainActor func pasteImportFailedFeatureRequestFlow_beginSubmitHidesConfirmAlert() {
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    #expect(flow.phase.showsConfirmAlert)
    #expect(flow.beginSubmit())
    #expect(flow.phase == .submitting)
    #expect(!flow.phase.showsConfirmAlert)
    flow.cancelOffer()
    #expect(flow.phase == .submitting)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_cancelConfirmAlertOnlyWhileConfirming() {
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    #expect(!flow.cancelConfirmAlert())
    flow.offer()
    #expect(flow.cancelConfirmAlert())
    #expect(flow.phase == .offering)
    flow.offer()
    #expect(flow.beginSubmit())
    #expect(!flow.cancelConfirmAlert())
    #expect(flow.phase == .submitting)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_modelFailureOfferThenStartConfirm() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteModelFailure()
    #expect(flow.canOffer)
    #expect(flow.phase == .idle)
    flow.offer()
    #expect(flow.phase == .confirming)
    await flow.startConfirm(
        source: .text("Hallo"),
        reason: .model,
        reporter: reporter,
        reporterGitHubUsername: nil
    ).value
    #expect(client.createCount == 1)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_resetClearsOffer() {
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    flow.reset()
    #expect(!flow.canOffer)
    #expect(flow.phase == .idle)
    flow.offer()
    #expect(flow.phase == .idle)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_offerFromSubmitFailed() async {
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
    guard case .submitFailed = flow.phase else {
        Issue.record("expected submitFailed")
        return
    }
    flow.offer()
    #expect(flow.phase == .confirming)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_offerIgnoredWhenAlreadyConfirming() {
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    flow.offer()
    #expect(flow.phase == .confirming)
}

@Test func pasteImportFailedFeatureRequestPhase_confirmAlertOnlyWhileConfirming() {
    #expect(PasteImportFailedFeatureRequestPhase.confirming.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.submitting.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.offering.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.idle.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.submitFailed("x").showsConfirmAlert)
    #expect(
        !PasteImportFailedFeatureRequestPhase.succeeded(
            URL(string: "https://github.com/rosch100/Reisen/issues/1")!
        ).showsConfirmAlert
    )
}
