import Foundation

/// HIG-Swipe-Policy für Buchungszeilen (iOS List). Pure SSOT; Views verdrahten Buttons.
public enum BookingRowSwipeAction: String, Equatable, Sendable, CaseIterable {
    case delete
    case removeFromTrip
    case createTripFromBooking
}

public enum BookingRowSwipeEdge: Equatable, Sendable {
    case trailing
    case leading
}

public enum BookingRowSwipeContext: Equatable, Sendable {
    /// `offersCreateTripOnLeading`: Compact-Phone-Liste; Split = false.
    case openBooking(offersCreateTripOnLeading: Bool)
    case tripAssignedBooking
}

public enum BookingRowSwipeActions {
    /// Geordnet: Index 0 = äußerste / primäre Swipe-Taste der Kante.
    public static func actions(
        for context: BookingRowSwipeContext,
        edge: BookingRowSwipeEdge
    ) -> [BookingRowSwipeAction] {
        switch (context, edge) {
        case (.tripAssignedBooking, .trailing):
            return [.delete]
        case (.tripAssignedBooking, .leading):
            return [.removeFromTrip]
        case (.openBooking, .trailing):
            return [.delete]
        case (.openBooking(let offersCreateTripOnLeading), .leading):
            return offersCreateTripOnLeading ? [.createTripFromBooking] : []
        }
    }
}
