import Testing
import ReisenDomain

@Test func pasteImportFailedRecognition_offersWhenCandidateCountIsZero() {
    #expect(PasteImportFailedRecognition.shouldOffer(candidateCount: 0))
}

@Test func pasteImportFailedRecognition_doesNotOfferWhenCandidatesExist() {
    #expect(!PasteImportFailedRecognition.shouldOffer(candidateCount: 1))
}

@Test func pasteImportFailedRecognition_offersModelFailureOnly() {
    #expect(PasteImportFailedRecognition.shouldOffer(failure: .model))
    #expect(!PasteImportFailedRecognition.shouldOffer(failure: .source))
    #expect(!PasteImportFailedRecognition.shouldOffer(failure: .modelUnavailable))
    #expect(!PasteImportFailedRecognition.shouldOffer(failure: .imageUnsupported))
}
