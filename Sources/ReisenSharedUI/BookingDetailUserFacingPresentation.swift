import Foundation

/// Read-only Gast-Hinweis (Titel + optional Detail, ohne Editor-Feldlabels).
public struct BookingGuestHintPresentation: Equatable, Sendable {
    /// Detail-UI nutzt keine `editor.hint_*`-Labels.
    public static var usesEditorFieldLabels: Bool { false }

    public let title: String
    public let detail: String?

    public static func make(title: String, detail: String) -> BookingGuestHintPresentation {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailOut: String?
        if trimmedDetail.isEmpty {
            detailOut = nil
        } else if trimmedDetail.caseInsensitiveCompare(trimmedTitle) == .orderedSame {
            detailOut = nil
        } else {
            detailOut = trimmedDetail
        }
        return BookingGuestHintPresentation(
            title: trimmedTitle.isEmpty ? title : trimmedTitle,
            detail: detailOut
        )
    }
}

/// Storno in der Detailanzeige: Parser-Heuristik `isStrict` nicht als Badge.
public enum BookingCancellationDeadlineUserFacing {
    public static var showsStrictBadgeInDetail: Bool { false }
}
