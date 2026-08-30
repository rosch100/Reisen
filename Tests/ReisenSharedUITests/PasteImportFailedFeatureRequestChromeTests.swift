import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test @MainActor func pasteImportFailedFeatureRequestPresentation_usesFeatureRequestCopy() {
    let presentation = PasteImportFailedFeatureRequestPresentation()
    #expect(!presentation.offerTitle.isEmpty)
    #expect(!presentation.sendTitle.isEmpty)
    #expect(!presentation.title.isEmpty)
    #expect(!presentation.doneTitle.isEmpty)
    #expect(
        presentation.offerTitle.localizedCaseInsensitiveContains("feature")
    )
    #expect(
        presentation.message.localizedCaseInsensitiveContains("öffentlich")
            || presentation.message.localizedCaseInsensitiveContains("public")
    )
    #expect(
        presentation.message.localizedCaseInsensitiveContains("e-mail")
            || presentation.message.localizedCaseInsensitiveContains("email")
    )
    #expect(!presentation.message.localizedCaseInsensitiveContains("base64"))
}

@Test func pasteImportFailedMailCompose_successSheetOnlyWhenMailUnavailable() {
    let url = URL(string: "https://github.com/rosch100/Reisen/issues/1")
    #expect(
        !PasteImportFailedMailCompose.showsSuccessSheet(
            successURL: url,
            hasMailDraft: true,
            submitError: nil,
            mailCanSend: false
        )
    )
    #expect(
        PasteImportFailedMailCompose.showsSuccessSheet(
            successURL: url,
            hasMailDraft: false,
            submitError: nil,
            mailCanSend: false
        )
    )
    #expect(
        !PasteImportFailedMailCompose.showsSuccessSheet(
            successURL: url,
            hasMailDraft: false,
            submitError: nil,
            mailCanSend: true
        )
    )
    #expect(
        !PasteImportFailedMailCompose.showsSuccessSheet(
            successURL: url,
            hasMailDraft: false,
            submitError: "Mail fehlgeschlagen",
            mailCanSend: false
        )
    )
}

@Test func pasteImportFailedMailCompose_sheetDismissDoesNotCompleteAfterComposerClearedDraft() {
    #expect(
        PasteImportFailedMailCompose.finishForDismissedMailSheet(hasDraft: true) == .completed
    )
    #expect(PasteImportFailedMailCompose.finishForDismissedMailSheet(hasDraft: false) == nil)
}

@Test func pasteImportCandidateSheetPresentation_showsFeatureButtonOnlyWhenEmptyAndAllowed() {
    let emptyOffer = PasteImportCandidateSheetPresentation(candidateCount: 0, canOfferFeatureRequest: true)
    #expect(emptyOffer.showsFeatureRequestButton)
    #expect(!emptyOffer.continueEnabled)

    let emptyDenied = PasteImportCandidateSheetPresentation(candidateCount: 0, canOfferFeatureRequest: false)
    #expect(!emptyDenied.showsFeatureRequestButton)

    let filled = PasteImportCandidateSheetPresentation(candidateCount: 2, canOfferFeatureRequest: true)
    #expect(!filled.showsFeatureRequestButton)
    #expect(filled.continueEnabled)
}
