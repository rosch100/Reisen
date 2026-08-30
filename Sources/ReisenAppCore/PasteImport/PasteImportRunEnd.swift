import Foundation
import ReisenDomain

/// Ergebnis nach Ende eines Paste-Import-Laufs: Accessibility-Text und Queue-Entscheidung.
public struct PasteImportRunEnd: Equatable, Sendable {
    public let announcement: String
    public let shouldAdvanceReviewQueue: Bool

    public init(
        cancelled: Bool,
        errorMessage: String?,
        hasPendingCandidates: Bool
    ) {
        if let errorMessage {
            announcement = errorMessage
        } else if cancelled {
            announcement = L10n.string(.pasteImportCancelled)
        } else if hasPendingCandidates {
            announcement = L10n.string(.pasteImportReviewReady)
        } else {
            announcement = L10n.string(.pasteImportEmpty)
        }
        shouldAdvanceReviewQueue =
            errorMessage == nil && !cancelled && hasPendingCandidates
    }
}

public extension PasteImportSessionControlling {
    var runEnd: PasteImportRunEnd {
        PasteImportRunEnd(
            cancelled: runWasCancelled,
            errorMessage: errorMessage,
            hasPendingCandidates: hasPendingCandidates
        )
    }
}
