import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

#if os(macOS)
import AppKit

@Test @MainActor func pasteImportMailCompose_finishForOpen_requiresMailtoDefaultApp() {
    #expect(
        PasteImportFailedMailCompose.finishForOpenResult(app: nil, error: nil)
            == .failed(L10n.string(.pasteImportFeatureRequestMailFailed))
    )
}

@Test @MainActor func pasteImportMailCompose_finishForOpen_propagatesOpenError() {
    let error = NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileReadUnknownError,
        userInfo: [NSLocalizedDescriptionKey: "open failed"]
    )
    let finish = PasteImportFailedMailCompose.finishForOpenResult(app: nil, error: error)
    #expect(finish == .failed("open failed"))
}
#endif
