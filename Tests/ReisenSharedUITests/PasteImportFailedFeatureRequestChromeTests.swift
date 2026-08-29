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
