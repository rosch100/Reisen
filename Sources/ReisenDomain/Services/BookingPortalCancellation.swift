import Foundation

public enum BookingPortalCancelPresentation: Equatable, Sendable {
    case sheet
    case safari
    case hidden
}

public enum BookingPortalCancellation {
    public static func isActionable(
        cancellation: URL?,
        open _: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date
    ) -> Bool {
        guard status != .cancelled, cancellation != nil else { return false }
        return !CancellationDeadlineDisplayFilter.deadlinesForDisplay(deadlines, now: now).isEmpty
    }

    public static func presentation(
        cancellation: URL?,
        open: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date,
        hasSessionWebView: Bool,
        requiresProviderSession: Bool
    ) -> BookingPortalCancelPresentation {
        guard isActionable(
            cancellation: cancellation,
            open: open,
            status: status,
            deadlines: deadlines,
            now: now
        ) else { return .hidden }
        if hasSessionWebView { return .sheet }
        if requiresProviderSession { return .hidden }
        if cancellation != open { return .safari }
        return .hidden
    }

    public static func allowsCopyingCancellationLink(cancel: URL?, open: URL?) -> Bool {
        guard let cancel else { return false }
        return cancel != open
    }
}

public enum BookingPortalActions {
    public struct Visible: Equatable, Sendable {
        public var open: URL?
        public var cancel: URL?
    }

    public static func visible(
        open: URL?,
        cancellation: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date,
        hasSessionWebView: Bool,
        requiresProviderSession: Bool
    ) -> Visible {
        let shown: URL?
        switch BookingPortalCancellation.presentation(
            cancellation: cancellation,
            open: open,
            status: status,
            deadlines: deadlines,
            now: now,
            hasSessionWebView: hasSessionWebView,
            requiresProviderSession: requiresProviderSession
        ) {
        case .sheet, .safari:
            shown = cancellation
        case .hidden:
            shown = nil
        }
        return Visible(open: open, cancel: shown)
    }
}
