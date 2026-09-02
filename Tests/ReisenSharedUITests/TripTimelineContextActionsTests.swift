import Foundation
import Testing
import ReisenSharedUI

@Suite
struct TripTimelineContextActionsTests {
    private func isBooking(_ id: String) -> Bool {
        UUID(uuidString: id) != nil
    }

    private func isGap(_ id: String) -> Bool {
        id.hasPrefix("gap|")
    }

    @Test func singleBooking_includesRemoveAndDelete() {
        let bookingID = UUID().uuidString
        let kind = TripTimelineContextActions.kind(
            selectedIDs: [bookingID],
            isBookingID: isBooking,
            isGapID: isGap
        )
        #expect(kind == .singleBooking)
        let actions = TripTimelineContextActions.actions(for: kind)
        #expect(actions.contains(.removeFromTrip))
        #expect(actions.contains(.deleteBooking))
        #expect(actions.contains(.edit))
    }

    @Test func multipleBookingsOnly_batchRemoveWithoutDelete() {
        let kind = TripTimelineContextActions.kind(
            selectedIDs: [UUID().uuidString, UUID().uuidString],
            isBookingID: isBooking,
            isGapID: isGap
        )
        #expect(kind == .multipleBookingsOnly)
        let actions = TripTimelineContextActions.actions(for: kind)
        #expect(actions.contains(.batchRemoveFromTrip))
        #expect(!actions.contains(.deleteBooking))
        #expect(!actions.contains(.removeFromTrip))
    }

    @Test func mixedOrGaps_noDestructiveBatch() {
        let bookingID = UUID().uuidString
        let kind = TripTimelineContextActions.kind(
            selectedIDs: [bookingID, "gap|demo"],
            isBookingID: isBooking,
            isGapID: isGap
        )
        #expect(kind == .mixedOrGapsOnly)
        let actions = TripTimelineContextActions.actions(for: kind)
        #expect(!actions.contains(.batchRemoveFromTrip))
        #expect(!actions.contains(.deleteBooking))
        #expect(!actions.contains(.removeFromTrip))
    }

    @Test func singleGap_editAndAddOnly() {
        let kind = TripTimelineContextActions.kind(
            selectedIDs: ["gap|demo"],
            isBookingID: isBooking,
            isGapID: isGap
        )
        #expect(kind == .singleGap)
        let actions = TripTimelineContextActions.actions(for: kind)
        #expect(actions.contains(.editGap))
        #expect(actions.contains(.addBooking))
    }
}
