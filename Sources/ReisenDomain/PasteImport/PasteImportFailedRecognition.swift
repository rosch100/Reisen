import Foundation

public enum PasteImportFailedRecognitionReason: Equatable, Sendable {
    case noCandidates
    case model
}

public enum PasteImportFailedRecognition: Sendable {
    public static func shouldOffer(candidateCount: Int) -> Bool {
        candidateCount == 0
    }

    public static func shouldOffer(failure: PasteImportFailure) -> Bool {
        failure == .model
    }
}
