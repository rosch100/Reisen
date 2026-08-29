import Foundation
import Testing
import ReisenDomain

private enum UnclassifiedPasteImportError: Error {
    case modelBroke
}

@Test func pasteImportFailure_classifiesEmptySourceAsSource() {
    #expect(PasteImportFailureMessage.failure(for: PasteImportSourceError.empty) == .source)
}

@Test func pasteImportFailure_classifiesUnknownErrorAsModel() {
    #expect(PasteImportFailureMessage.failure(for: UnclassifiedPasteImportError.modelBroke) == .model)
}

@Test func pasteImportFailure_usesOneKeyPerFailure() {
    let keys: [L10nKey] = [
        PasteImportFailure.source.messageKey,
        PasteImportFailure.modelUnavailable.messageKey,
        PasteImportFailure.imageUnsupported.messageKey,
        PasteImportFailure.model.messageKey,
    ]
    #expect(Set(keys.map(\.rawValue)).count == keys.count)
}

@Test func pasteImportFailure_textComesFromCatalog() {
    #expect(
        PasteImportFailureMessage.text(for: PasteImportSourceError.empty)
            == L10n.string(.pasteImportErrorSource)
    )
    #expect(
        PasteImportFailureMessage.text(for: UnclassifiedPasteImportError.modelBroke)
            == L10n.string(.pasteImportErrorModel)
    )
}
