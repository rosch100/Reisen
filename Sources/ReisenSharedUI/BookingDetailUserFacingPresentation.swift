import Foundation

/// Read-only Gast-Hinweis (Titel + optional Detail, ohne Editor-Feldlabels).
public struct BookingGuestHintPresentation: Equatable, Sendable {
    /// Detail-UI nutzt keine `editor.hint_*`-Labels.
    public static var usesEditorFieldLabels: Bool { false }

    public let title: String
    public let detail: String?

    public static func make(title: String, detail: String) -> BookingGuestHintPresentation {
        BookingGuestHintPresentation(
            title: title,
            detail: detail.isEmpty ? nil : detail
        )
    }
}

/// Storno in der Detailanzeige: Parser-Heuristik `isStrict` nicht als Badge.
public enum BookingCancellationDeadlineUserFacing {
    public static var showsStrictBadgeInDetail: Bool { false }
}
