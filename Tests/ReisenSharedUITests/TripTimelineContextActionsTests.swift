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

    @Test func multipleBookings_batchRemoveAndBatchDelete() {
        let kind = TripTimelineContextActions.kind(
            selectedIDs: [UUID().uuidString, UUID().uuidString],
            isBookingID: isBooking,
            isGapID: isGap
        )
        #expect(kind == .multipleBookings)
        let actions = TripTimelineContextActions.actions(for: kind)
        #expect(actions.contains(.batchRemoveFromTrip))
        #expect(actions.contains(.batchDeleteBooking))
        #expect(!actions.contains(.deleteBooking))
        #expect(!actions.contains(.removeFromTrip))
    }

    @Test func multipleBookingsWithInterveningGap_offersBatchOnBookingSubset() {
        let bookingA = UUID().uuidString
        let bookingB = UUID().uuidString
        let selected: Set<String> = [bookingA, "gap|between", bookingB]
        let kind = TripTimelineContextActions.kind(
            selectedIDs: selected,
            isBookingID: isBooking,
            isGapID: isGap
        )
        // Nutzer-Intent / native ⇧-Range: Gaps zwischen Buchungen dürfen Batch nicht blockieren.
        #expect(kind == .multipleBookings)
        let actions = TripTimelineContextActions.actions(for: kind)
        #expect(actions.contains(.batchRemoveFromTrip))
        #expect(actions.contains(.batchDeleteBooking))
        #expect(
            TripTimelineContextActions.bookingIDs(in: selected, isBookingID: isBooking)
                == [bookingA, bookingB]
        )
    }

    @Test func mixedOrGaps_singleBookingPlusGap_noDestructiveBatch() {
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

    @Test func gapsOnly_noDestructiveBatch() {
        let kind = TripTimelineContextActions.kind(
            selectedIDs: ["gap|a", "gap|b"],
            isBookingID: isBooking,
            isGapID: isGap
        )
        #expect(kind == .mixedOrGapsOnly)
        let actions = TripTimelineContextActions.actions(for: kind)
        #expect(actions.isEmpty)
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
