import Foundation
import Testing
import ReisenSharedUI

@Suite
struct BookingRowSwipeActionsTests {
    @Test func tripAssigned_trailingIsDeleteOnly() {
        #expect(
            BookingRowSwipeActions.actions(for: .tripAssignedBooking, edge: .trailing)
                == [.delete]
        )
    }

    @Test func tripAssigned_leadingIsRemoveFromTrip() {
        #expect(
            BookingRowSwipeActions.actions(for: .tripAssignedBooking, edge: .leading)
                == [.removeFromTrip]
        )
    }

    @Test func openCompact_trailingIsDelete() {
        #expect(
            BookingRowSwipeActions.actions(
                for: .openBooking(offersCreateTripOnLeading: true),
                edge: .trailing
            ) == [.delete]
        )
    }

    @Test func openSplit_trailingIsDelete() {
        #expect(
            BookingRowSwipeActions.actions(
                for: .openBooking(offersCreateTripOnLeading: false),
                edge: .trailing
            ) == [.delete]
        )
    }

    @Test func openCompact_leadingCreateTrip() {
        #expect(
            BookingRowSwipeActions.actions(
                for: .openBooking(offersCreateTripOnLeading: true),
                edge: .leading
            ) == [.createTripFromBooking]
        )
    }

    @Test func openSplit_leadingEmpty() {
        #expect(
            BookingRowSwipeActions.actions(
                for: .openBooking(offersCreateTripOnLeading: false),
                edge: .leading
            ).isEmpty
        )
    }

    @Test func swipeIdentifiers_areStableAndDistinct() {
        #expect(UITestingIdentifiers.swipeBookingDelete == "reisen.swipe.booking.delete")
        #expect(
            UITestingIdentifiers.swipeBookingRemoveFromTrip
                == "reisen.swipe.booking.remove-from-trip"
        )
        #expect(
            UITestingIdentifiers.swipeBookingDelete
                != UITestingIdentifiers.swipeBookingRemoveFromTrip
        )
    }
}
