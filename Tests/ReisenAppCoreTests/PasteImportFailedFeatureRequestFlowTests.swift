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
    #expect(flow.beginSubmit())
    await flow.confirm(
        source: .text("Hallo"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
    #expect(flow.phase == .succeeded(URL(string: "https://github.com/rosch100/Reisen/issues/1")!))
    #expect(!flow.canOffer)
    #expect(flow.mailDraft?.data == Data("Hallo".utf8))
    #expect(flow.mailDraft?.body.contains(PasteImportFailedMailDraft.skipIngressMarker) == true)
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
    #expect(!flow.beginSubmit())
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
    #expect(flow.beginSubmit())
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
    #expect(flow.beginSubmit())
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

@Test @MainActor func pasteImportFailedFeatureRequestFlow_applyRunResultOffersOnlyWhenEmpty() {
    let flow = PasteImportFailedFeatureRequestFlow()
    let empty = flow.applyRunResult(PasteImportRunResult(candidates: []))
    #expect(empty == .noCandidates)
    #expect(flow.canOffer)
    #expect(flow.phase == .offering)

    let candidate = PasteImportCandidate(
        draft: PasteImportDraft(
            bookingType: .hotel,
            startAt: Date(timeIntervalSince1970: 1),
            endAt: Date(timeIntervalSince1970: 2),
            endAtIsPlaceholder: false,
            title: "Hotel",
            status: .unknown
        ),
        match: .none
    )
    let filled = flow.applyRunResult(PasteImportRunResult(candidates: [candidate]))
    #expect(filled == nil)
    #expect(!flow.canOffer)
    #expect(flow.phase == .idle)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_applyRunFailureOffersOnlyModel() {
    let flow = PasteImportFailedFeatureRequestFlow()
    #expect(flow.applyRunFailure(.model) == .model)
    #expect(flow.canOffer)
    #expect(flow.phase == .idle)
    #expect(flow.applyRunFailure(.source) == nil)
    #expect(!flow.canOffer)
    #expect(flow.applyRunFailure(.imageUnsupported) == nil)
    #expect(!flow.canOffer)
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_mailComposeFailedAfterSuccessKeepsURL() async {
    let flow = await flowAfterSuccessfulFeatureRequest()
    flow.finishMailCompose(.failed("Mail fehlgeschlagen"))
    #expect(flow.mailDraft == nil)
    #expect(flow.mailComposeError == "Mail fehlgeschlagen")
    #expect(flow.phase == .succeeded(pasteImportFailedIssueURL))
    flow.finishMailCompose(.completed)
    #expect(flow.mailComposeError == nil)
    #expect(flow.phase == .succeeded(pasteImportFailedIssueURL))
}

@Test @MainActor func pasteImportFailedFeatureRequestFlow_mailComposeCompletedClearsDraft() async {
    let flow = await flowAfterSuccessfulFeatureRequest()
    flow.finishMailCompose(.completed)
    #expect(flow.mailDraft == nil)
    #expect(flow.mailComposeError == nil)
    #expect(flow.phase == .succeeded(pasteImportFailedIssueURL))
}

@Test func pasteImportFailedMailComposeFinish_fromSharingCancellationIsCompleted() {
    let cancelled = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    #expect(PasteImportFailedMailComposeFinish.fromSharingFailure(cancelled) == .completed)
}

@Test func pasteImportFailedMailComposeFinish_fromSharingErrorIsFailed() {
    let error = NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteNoPermissionError,
        userInfo: [NSLocalizedDescriptionKey: "keine Berechtigung"]
    )
    #expect(PasteImportFailedMailComposeFinish.fromSharingFailure(error) == .failed("keine Berechtigung"))
}

@Test func pasteImportFailedMailComposeFinish_fromSharingEmptyDescriptionUsesFallback() {
    let error = NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteNoPermissionError,
        userInfo: [NSLocalizedDescriptionKey: "  "]
    )
    #expect(
        PasteImportFailedMailComposeFinish.fromSharingFailure(error)
            == .failed(L10n.string(.pasteImportFeatureRequestMailFailed))
    )
}

@Test func pasteImportFailedMailComposeFinish_fromComposerFailedUsesFallbackWhenEmpty() {
    let finish = PasteImportFailedMailComposeFinish.fromComposer(didFail: true, error: nil)
    #expect(finish == .failed(L10n.string(.pasteImportFeatureRequestMailFailed)))
}

@Test func pasteImportFailedMailComposeFinish_fromComposerMapsFailAndError() {
    #expect(PasteImportFailedMailComposeFinish.fromComposer(didFail: false, error: nil) == .completed)
    let cancelled = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    #expect(PasteImportFailedMailComposeFinish.fromComposer(didFail: false, error: cancelled) == .completed)
}

@Test func pasteImportFailedMailAttachmentFile_writesUniqueDirectoryAndRemovesContainer() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString,
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let fileURL = try PasteImportFailedMailAttachmentFile.writeUnique(
        data: Data("PNR ABC".utf8),
        fileName: "paste.txt",
        temporaryDirectory: root
    )
    #expect(fileURL.lastPathComponent == "paste.txt")
    #expect(fileURL.deletingLastPathComponent().lastPathComponent != "paste.txt")
    #expect(try Data(contentsOf: fileURL) == Data("PNR ABC".utf8))
    let sibling = root.appending(path: "paste.txt")
    #expect(fileURL != sibling)

    try PasteImportFailedMailAttachmentFile.removeContainer(of: fileURL)
    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
}

@Test func pasteImportFailedMailAttachmentFile_writeFailureDoesNotLeaveDirectory() {
    let blocker = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    FileManager.default.createFile(atPath: blocker.path, contents: Data())
    defer { try? FileManager.default.removeItem(at: blocker) }

    #expect(throws: (any Error).self) {
        try PasteImportFailedMailAttachmentFile.writeUnique(
            data: Data("x".utf8),
            fileName: "paste.txt",
            temporaryDirectory: blocker
        )
    }
}

@Test func pasteImportFailedFeatureRequestPhase_confirmAlertOnlyWhileConfirming() {
    #expect(PasteImportFailedFeatureRequestPhase.confirming.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.submitting.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.offering.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.idle.showsConfirmAlert)
    #expect(!PasteImportFailedFeatureRequestPhase.submitFailed("x").showsConfirmAlert)
    #expect(
        !PasteImportFailedFeatureRequestPhase.succeeded(pasteImportFailedIssueURL).showsConfirmAlert
    )
}

private let pasteImportFailedIssueURL = URL(string: "https://github.com/rosch100/Reisen/issues/1")!

@MainActor
private func flowAfterSuccessfulFeatureRequest() async -> PasteImportFailedFeatureRequestFlow {
    let reporter = GitHubIssueReporter(
        client: MockGitHubIssues(),
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let flow = PasteImportFailedFeatureRequestFlow()
    flow.noteEmptyCandidates()
    flow.offer()
    await flow.startConfirm(
        source: .text("Hallo"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    ).value
    return flow
}
