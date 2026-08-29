import Foundation
import Testing
import ReisenAppCore

@Test func pasteImportDrop_startsWhenIdleAndFileAccepted() {
    #expect(
        PasteImportDropCoordinator.action(
            offeredURLCount: 1,
            acceptedFileCount: 1,
            isSessionActive: false
        ) == .start
    )
}

@Test func pasteImportDrop_ignoresWhileSessionIsActive() {
    #expect(
        PasteImportDropCoordinator.action(
            offeredURLCount: 1,
            acceptedFileCount: 1,
            isSessionActive: true
        ) == .ignore
    )
    #expect(
        PasteImportDropCoordinator.action(
            offeredURLCount: 2,
            acceptedFileCount: 0,
            isSessionActive: true
        ) == .ignore
    )
}

@Test func pasteImportDrop_failsWhenIdleButNoAcceptedFile() {
    #expect(
        PasteImportDropCoordinator.action(
            offeredURLCount: 1,
            acceptedFileCount: 0,
            isSessionActive: false
        ) == .fail
    )
}

@Test func pasteImportDrop_ignoresEmptyOffer() {
    #expect(
        PasteImportDropCoordinator.action(
            offeredURLCount: 0,
            acceptedFileCount: 0,
            isSessionActive: false
        ) == .ignore
    )
}
