import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

@Test func pasteImportAdapterError_classifiesEveryCase() {
    #expect(PasteImportAdapterError.unavailable.pasteImportFailure == .modelUnavailable)
    #expect(PasteImportAdapterError.unreadableSource.pasteImportFailure == .source)
    #expect(PasteImportAdapterError.imageConversionFailed.pasteImportFailure == .source)
    #expect(PasteImportAdapterError.imageInputUnsupported.pasteImportFailure == .imageUnsupported)
}

@Test func pasteImportAdapterError_messageComesFromSharedMapping() {
    #expect(
        PasteImportFailureMessage.text(for: PasteImportAdapterError.imageInputUnsupported)
            == L10n.string(.pasteImportErrorImageUnsupported)
    )
}
