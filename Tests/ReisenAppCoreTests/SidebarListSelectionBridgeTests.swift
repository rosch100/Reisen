import Foundation
import Testing
import ReisenDomain
@testable import ReisenAppCore

struct SidebarListSelectionBridgeTests {
    private let bookingA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
    private let bookingB = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2")!
    private let trip1 = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1")!
    private let trip2 = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!

    @Test func openMailboxProjectsEverySelectedBookingAsListTag() {
        let ids = SidebarListSelectionBridge.listIDs(
            providerID: nil,
            mailbox: .current,
            openBookingIDs: [bookingA, bookingB],
            selectedTripIDs: [],
            tripBookingIDs: []
        )
        #expect(ids == [.openBooking(bookingA), .openBooking(bookingB)])
    }

    @Test func tripBookingsProjectWithoutParentTripTag() {
        let ids = SidebarListSelectionBridge.listIDs(
            providerID: nil,
            mailbox: nil,
            openBookingIDs: [],
            selectedTripIDs: [trip1],
            tripBookingIDs: [bookingA, bookingB]
        )
        #expect(ids == [.tripBooking(bookingA), .tripBooking(bookingB)])
        #expect(!ids.contains(.trip(trip1)))
    }

    @Test func tripsProjectWhenNoTripBookingsSelected() {
        let ids = SidebarListSelectionBridge.listIDs(
            providerID: nil,
            mailbox: nil,
            openBookingIDs: [],
            selectedTripIDs: [trip1, trip2],
            tripBookingIDs: []
        )
        #expect(ids == [.trip(trip1), .trip(trip2)])
    }

    @Test func menuKindForMultipleOpenBookingsIsBatch() {
        let kind = SidebarListSelectionBridge.menuKind(
            for: [.openBooking(bookingA), .openBooking(bookingB)]
        )
        #expect(kind == .openBookings(count: 2))
    }

    @Test func boundMergeKeepsAllOpenBookingListTags() {
        let bound: Set<SidebarListItemID> = [.openBooking(bookingA), .openBooking(bookingB)]
        let effective = MenuEffectiveSelection.resolve(
            menu: [.openBooking(bookingB)],
            bound: bound
        )
        #expect(effective == bound)
        #expect(SidebarListSelectionBridge.menuKind(for: effective) == .openBookings(count: 2))
    }

    @Test func applyOpenBookingTagsSetsMailboxAndClearsTrips() throws {
        let result = SidebarListSelectionBridge.apply(
            listIDs: [.openBooking(bookingA), .openBooking(bookingB)],
            tripIDForBooking: { _ in nil }
        )
        let applied = try #require(result)
        #expect(applied.mailbox == .current)
        #expect(applied.openBookingIDs == [bookingA, bookingB])
        #expect(applied.tripIDs.isEmpty)
        #expect(applied.tripBookingIDs.isEmpty)
        #expect(applied.providerID == nil)
    }

    @Test func applyMixedTagsIsRejected() {
        let result = SidebarListSelectionBridge.apply(
            listIDs: [.openBooking(bookingA), .trip(trip1)],
            tripIDForBooking: { _ in trip1 }
        )
        #expect(result == nil)
    }

    @Test func menuKindForMixedTagsIsMixed() {
        let kind = SidebarListSelectionBridge.menuKind(
            for: [.openBooking(bookingA), .trip(trip1)]
        )
        #expect(kind == .mixed)
    }
}
