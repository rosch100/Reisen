import Foundation
import Testing
import ReisenSharedUI

/// Erwartete Sidebar-/Listen-Kontextaktionen (Parity vs. aktuelle Reisen).
@Suite
struct SidebarEntryContextActionsTests {
    @Test func tripActions_includeEditAddAndDelete() {
        let actions = SidebarEntryContextActions.actions(for: .trip)
        #expect(actions.contains(.edit))
        #expect(actions.contains(.addBooking))
        #expect(actions.contains(.deleteTrip))
    }

    @Test func tripBookingActions_includeDeleteAndRemoveFromTrip() {
        let actions = SidebarEntryContextActions.actions(for: .tripBooking)
        #expect(actions.contains(.edit))
        #expect(actions.contains(.addBooking))
        #expect(actions.contains(.deleteBooking))
        #expect(actions.contains(.removeFromTrip))
    }

    @Test func openBookingMailboxActions_includeCreateTripFromAll() {
        let actions = SidebarEntryContextActions.actions(for: .openBookingMailbox)
        #expect(actions.contains(.createTripFromAllOpen))
    }

    @Test func openBookingActions_includeDelete() {
        let actions = SidebarEntryContextActions.actions(for: .openBooking)
        #expect(actions.contains(.deleteBooking))
        #expect(actions.contains(.createTripFromSelection))
    }

    @Test func elapsedOpenBookingActions_matchOpenBookingIncludingDelete() {
        let open = SidebarEntryContextActions.actions(for: .openBooking)
        let elapsed = SidebarEntryContextActions.actions(for: .elapsedOpenBooking)
        #expect(elapsed == open)
        #expect(elapsed.contains(.deleteBooking))
    }

    @Test func elapsedTripActions_matchCurrentTripIncludingAddBooking() {
        let current = SidebarEntryContextActions.actions(for: .trip)
        let elapsed = SidebarEntryContextActions.actions(for: .elapsedTrip)
        #expect(elapsed == current)
        #expect(elapsed.contains(.addBooking))
        #expect(elapsed.contains(.deleteTrip))
    }

    @Test func openAndElapsedMailbox_shareCreateTripAction() {
        let open = SidebarEntryContextActions.actions(for: .openBookingMailbox)
        let elapsed = SidebarEntryContextActions.actions(for: .elapsedOpenBookingMailbox)
        #expect(elapsed == open)
        #expect(elapsed.contains(.createTripFromAllOpen))
    }
}
