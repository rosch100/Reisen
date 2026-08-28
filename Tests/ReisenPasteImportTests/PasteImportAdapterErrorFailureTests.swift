import Foundation
import Testing
import ReisenDomain
@testable import ReisenPasteImport

@Test func pasteImportAdapterError_classifiesEveryCase() {
    #expect(PasteImportAdapterError.unavailable.pasteImportFailure == .modelUnavailable)
    #expect(PasteImportAdapterError.unreadableSource.pasteImportFailure == .source)
    #expect(PasteImportAdapterError.imageConversionFailed.pasteImportFailure == .source)
    #expect(PasteImportAdapterError.imageInputUnsupported.pasteImportFailure == .imageUnsupported)
}

@Test func pasteImportImageAttachments_unsupportedThrowsImageInputUnsupported() {
    #expect(throws: PasteImportAdapterError.imageInputUnsupported) {
        try PasteImportImageAttachments.requireSupport(false)
    }
}
