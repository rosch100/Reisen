import Foundation

/// iOS Trip-Timeline: Detail-Push über Item-Binding, nicht NavigationLink(value:) unter path-Stack.
public enum TripBookingDetailNavigation {
    /// Tip auf Timeline-Buchung → `navigationDestination(item:)`.
    public static func applyUserSelect(bookingID: UUID, presentedBookingID: inout UUID?) {
        presentedBookingID = bookingID
    }
}
