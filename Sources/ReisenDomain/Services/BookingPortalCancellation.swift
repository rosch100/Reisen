import Foundation

public enum BookingPortalCancellation {
    public static func isActionable(
        cancellation: URL?,
        open: URL?,
        status: BookingStatus
    ) -> Bool {
        guard status != .cancelled, let cancellation else { return false }
        return cancellation != open
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
        status: BookingStatus
    ) -> Visible {
        Visible(
            open: open,
            cancel: BookingPortalCancellation.isActionable(
                cancellation: cancellation,
                open: open,
                status: status
            ) ? cancellation : nil
        )
    }
}
