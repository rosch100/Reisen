import Foundation

public enum SidebarOpenBookingMailbox: Equatable, Sendable {
    case current
    case elapsed
}

public enum SidebarBookingOutlineFocus {
    public static func select(
        mailbox: SidebarOpenBookingMailbox,
        bookingID: UUID
    ) -> (mailbox: SidebarOpenBookingMailbox, selectedIDs: Set<UUID>) {
        (mailbox, [bookingID])
    }
}
