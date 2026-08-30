import Foundation
import Testing
import ReisenAppCore
import ReisenDomain

@Test func pasteImportRunEnd_prefersError() {
    let end = PasteImportRunEnd(
        cancelled: true,
        errorMessage: "Modellfehler",
        hasPendingCandidates: true
    )
    #expect(end.announcement == "Modellfehler")
    #expect(!end.shouldAdvanceReviewQueue)
}

@Test func pasteImportRunEnd_cancelledNotEmpty() {
    let end = PasteImportRunEnd(
        cancelled: true,
        errorMessage: nil,
        hasPendingCandidates: false
    )
    #expect(end.announcement == L10n.string(.pasteImportCancelled))
    #expect(end.announcement != L10n.string(.pasteImportEmpty))
    #expect(!end.shouldAdvanceReviewQueue)
}

@Test func pasteImportRunEnd_candidatesReadyNotListTitle() {
    let end = PasteImportRunEnd(
        cancelled: false,
        errorMessage: nil,
        hasPendingCandidates: true
    )
    #expect(end.announcement == L10n.string(.pasteImportReviewReady))
    #expect(end.announcement != L10n.string(.pasteImportCandidatesTitle))
    #expect(end.shouldAdvanceReviewQueue)
}

@Test func pasteImportRunEnd_emptyWhenNoCandidates() {
    let end = PasteImportRunEnd(
        cancelled: false,
        errorMessage: nil,
        hasPendingCandidates: false
    )
    #expect(end.announcement == L10n.string(.pasteImportEmpty))
    #expect(!end.shouldAdvanceReviewQueue)
}

@Test func pasteImportRunEnd_errorBlocksQueueEvenWithPending() {
    let end = PasteImportRunEnd(
        cancelled: false,
        errorMessage: "Fehler",
        hasPendingCandidates: true
    )
    #expect(!end.shouldAdvanceReviewQueue)
}
