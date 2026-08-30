import Foundation
import Testing
import ReisenDomain
import ReisenAppCore
@testable import ReisenSharedUI

@Test @MainActor func pasteImportMailCompose_configurationUsesDraftWithoutSender() {
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
    let draft = PasteImportFailedMailDraft.make(source: .pdf(pdf), issueURL: nil)
    let configuration = PasteImportFailedMailCompose.makeConfiguration(draft: draft)

    #expect(configuration.recipients == [GitHubRepository.feedbackEmail])
    #expect(configuration.subject == draft.subject)
    #expect(configuration.body == draft.body)
    #expect(configuration.attachmentData == pdf)
    #expect(configuration.mimeType == "application/pdf")
    #expect(configuration.fileName == "paste.pdf")
    #expect(configuration.fileName.split(separator: ".").last != "eml")
}

@Test func pasteImportMailCompose_failedErrorUsesLocalizedDescription() {
    #expect(
        PasteImportFailedMailComposeError.failed.errorDescription
            == L10n.string(.pasteImportFeatureRequestMailFailed)
    )
}

@Test @MainActor func pasteImportMailCompose_appearingDraftWithoutDraftDoesNothing() {
    var unavailable = false
    var presented = false
    var failed = false
    PasteImportFailedMailCompose.handleAppearingDraft(
        draft: nil,
        mailCanSend: true,
        finishUnavailable: { unavailable = true },
        presentDraft: { _ in presented = true },
        finishPresentFailure: { _ in failed = true }
    )
    #expect(!unavailable)
    #expect(!presented)
    #expect(!failed)
}

@Test @MainActor func pasteImportMailCompose_appearingDraftWithoutMailFinishesUnavailable() {
    let draft = PasteImportFailedMailDraft.make(source: .text("PNR"), issueURL: nil)
    var unavailable = false
    PasteImportFailedMailCompose.handleAppearingDraft(
        draft: draft,
        mailCanSend: false,
        finishUnavailable: { unavailable = true },
        presentDraft: { _ in Issue.record("present must not run") },
        finishPresentFailure: { _ in Issue.record("failure must not run") }
    )
    #expect(unavailable)
}

#if os(macOS)
import AppKit

@Test @MainActor func pasteImportMailCompose_preparesDefaultAccountComposerWithDocumentAttachment() throws {
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31])
    let draft = PasteImportFailedMailDraft.make(source: .pdf(pdf), issueURL: nil)
    let prepared = try PasteImportFailedMailCompose.prepare(draft)
    defer { PasteImportFailedMailAttachmentFile.removeContainerIfPresent(of: prepared.attachmentURL) }

    #expect(prepared.configuration == PasteImportFailedMailCompose.makeConfiguration(draft: draft))
    #expect(prepared.attachmentURL.lastPathComponent == draft.fileName)
    #expect(prepared.attachmentURL.pathExtension == "pdf")
    #expect(try Data(contentsOf: prepared.attachmentURL) == pdf)

    let service = try #require(NSSharingService(named: .composeEmail))
    let items = PasteImportFailedMailCompose.apply(prepared, to: service)
    #expect(service.recipients == [GitHubRepository.feedbackEmail])
    #expect(service.subject == draft.subject)
    #expect(items.count == 2)
    #expect(items[0] as? String == draft.body)
    #expect(items[1] as? URL == prepared.attachmentURL)
}

@Suite(.serialized)
@MainActor
struct PasteImportMailComposeShareTests {
    @Test func presentWithoutServiceThrows() {
        let draft = PasteImportFailedMailDraft.make(source: .text("PNR"), issueURL: nil)
        #expect(throws: PasteImportFailedMailComposeError.self) {
            try PasteImportFailedMailCompose.present(
                draft,
                using: nil,
                perform: { _, _ in },
                onFinished: { _ in }
            )
        }
    }

    @Test func presentAppliesComposeEmailWithoutOpeningMailer() throws {
        let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x32])
        let draft = PasteImportFailedMailDraft.make(source: .pdf(pdf), issueURL: nil)
        let service = try #require(NSSharingService(named: .composeEmail))
        var performedItems: [Any] = []
        let fileURL = try PasteImportFailedMailCompose.present(
            draft,
            using: service,
            perform: { _, items in performedItems = items },
            onFinished: { _ in }
        )
        defer {
            PasteImportFailedMailCompose.shareLifetime = nil
            PasteImportFailedMailAttachmentFile.removeContainerIfPresent(of: fileURL)
        }

        #expect(service.recipients == [GitHubRepository.feedbackEmail])
        #expect(service.subject == draft.subject)
        #expect(PasteImportFailedMailCompose.shareLifetime != nil)
        #expect(performedItems.count == 2)
        #expect(performedItems[0] as? String == draft.body)
        #expect(performedItems[1] as? URL == fileURL)
        #expect(fileURL.pathExtension == "pdf")
        #expect(try Data(contentsOf: fileURL) == pdf)
    }

    @Test func completeShareWithoutLifetimeDoesNotFinish() {
        var finished = false
        PasteImportFailedMailCompose.shareLifetime = nil
        PasteImportFailedMailCompose.completeShare(
            fileURL: URL(fileURLWithPath: "/tmp/missing.pdf"),
            finish: .completed,
            onFinished: { _ in finished = true }
        )
        #expect(!finished)
    }

    @Test func completeShareRemovesAttachmentAndFinishes() throws {
        let fileURL = try PasteImportFailedMailAttachmentFile.writeUnique(
            data: Data("doc".utf8),
            fileName: "paste.txt"
        )
        PasteImportFailedMailCompose.shareLifetime = MailShareLifetime(
            fileURL: fileURL,
            onFinished: { _ in }
        )
        var finish: PasteImportFailedMailComposeFinish?
        PasteImportFailedMailCompose.completeShare(
            fileURL: fileURL,
            finish: .completed,
            onFinished: { finish = $0 }
        )
        #expect(finish == .completed)
        #expect(PasteImportFailedMailCompose.shareLifetime == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}

@Test @MainActor func pasteImportMailCompose_appearingDraftPresentsOnMacOS() {
    let draft = PasteImportFailedMailDraft.make(source: .text("PNR"), issueURL: nil)
    var presentedTo: String?
    PasteImportFailedMailCompose.handleAppearingDraft(
        draft: draft,
        mailCanSend: true,
        finishUnavailable: { Issue.record("unavailable must not run") },
        presentDraft: { presentedTo = $0.to },
        finishPresentFailure: { _ in Issue.record("failure must not run") }
    )
    #expect(presentedTo == GitHubRepository.feedbackEmail)
}

@Test @MainActor func pasteImportMailCompose_appearingDraftMapsPresentFailure() {
    let draft = PasteImportFailedMailDraft.make(source: .text("PNR"), issueURL: nil)
    var failure: String?
    PasteImportFailedMailCompose.handleAppearingDraft(
        draft: draft,
        mailCanSend: true,
        finishUnavailable: { Issue.record("unavailable must not run") },
        presentDraft: { _ in throw PasteImportFailedMailComposeError.failed },
        finishPresentFailure: { failure = $0.localizedDescription }
    )
    #expect(failure == L10n.string(.pasteImportFeatureRequestMailFailed))
}

@Test @MainActor func pasteImportMailCompose_canSendMatchesComposeEmailAndMailtoHandler() {
    let service = NSSharingService(named: .composeEmail)
    let mailto = URL(string: "mailto:")
    let hasMailtoHandler = mailto.flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) } != nil
    let serviceCanCompose = service?.canPerform(withItems: [""]) == true
    #expect(PasteImportFailedMailCompose.canSend == (service != nil && hasMailtoHandler && serviceCanCompose))
}

@Test @MainActor func pasteImportMailCompose_sessionSuccessSheetUsesCanSendAndDraft() {
    let session = MailComposeSessionStub()
    session.featureRequestSuccessURL = URL(string: "https://github.com/rosch100/Reisen/issues/1")
    session.featureRequestMailDraft = nil
    #expect(
        PasteImportFailedMailCompose.showsSuccessSheet(session)
            == !PasteImportFailedMailCompose.canSend
    )
}

@Test @MainActor func pasteImportMailCompose_sessionDismissWithoutDraftDoesNotFinish() {
    let session = MailComposeSessionStub()
    PasteImportFailedMailCompose.finishDismissedMailSheet(session)
    #expect(session.finished == nil)
}

@Test @MainActor func pasteImportMailCompose_sessionDismissWithDraftFinishesCompleted() {
    let session = MailComposeSessionStub()
    session.featureRequestMailDraft = PasteImportFailedMailDraft.make(source: .text("PNR"), issueURL: nil)
    PasteImportFailedMailCompose.finishDismissedMailSheet(session)
    #expect(session.finished == .completed)
    #expect(session.closedOnCompleted == false)
}

@Test @MainActor func pasteImportMailCompose_sessionAppearingDraftWithoutDraftIsNoOp() {
    let session = MailComposeSessionStub()
    PasteImportFailedMailCompose.handleAppearingDraft(session: session, mailCanSend: true)
    #expect(session.finished == nil)
}

@Test @MainActor func pasteImportMailCompose_sessionAppearingDraftWithoutMailFinishes() {
    let session = MailComposeSessionStub()
    session.featureRequestMailDraft = PasteImportFailedMailDraft.make(source: .text("PNR"), issueURL: nil)
    PasteImportFailedMailCompose.handleAppearingDraft(session: session, mailCanSend: false)
    #expect(session.finished == .completed)
    #expect(session.closedOnCompleted == false)
}
#endif

@MainActor
private final class MailComposeSessionStub: PasteImportSessionControlling {
    var isConfirmingPrivateCloudCompute = false
    var isPresentingSheet = false
    var runningKind: PasteImportModelKind?
    var isRunning = false
    var choosingResult: PasteImportRunResult?
    var errorMessage: String?
    var canOfferFeatureRequest = false
    var isConfirmingFeatureRequest = false
    var featureRequestSuccessURL: URL?
    var featureRequestSubmitError: String?
    var featureRequestMailDraft: PasteImportFailedMailDraft?
    var hasPendingCandidates = false
    var runWasCancelled = false
    var finished: PasteImportFailedMailComposeFinish?
    var closedOnCompleted: Bool?

    func confirmPrivateCloudCompute() {}
    func cancelConfirmation() {}
    func cancelRun() {}
    func dismissSheet() {}
    func review() {}
    func dismissError() {}
    func offerFailedFeatureRequest() {}
    func cancelFailedFeatureRequest() {}
    func confirmFailedFeatureRequest() {}
    func dismissFeatureRequestSuccess() {}
    func dismissFeatureRequestSubmitError() {}
    func finishFeatureRequestMail(
        _ finish: PasteImportFailedMailComposeFinish,
        closesSessionOnCompleted: Bool
    ) {
        finished = finish
        closedOnCompleted = closesSessionOnCompleted
    }
}
