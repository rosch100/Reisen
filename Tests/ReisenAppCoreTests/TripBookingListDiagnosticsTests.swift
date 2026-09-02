import Foundation
import Testing
import ReisenDiagnostics
@testable import ReisenAppCore

@Suite
struct TripBookingListDiagnosticsTests {
    @Test func removeFromTripBatch_fields() {
        let event = TripBookingListDiagnostics.removeFromTripBatch(result: .started, count: 3)
        #expect(event.component == "TripBookingList")
        #expect(event.phase == "selection_action")
        #expect(event.event == "remove_from_trip_batch")
        #expect(event.result == .started)
        #expect(event.reason == "count=3")
    }

    @Test func removeFromTripBatch_failedIncludesErrorType() {
        let event = TripBookingListDiagnostics.removeFromTripBatch(
            result: .failed,
            count: 2,
            errorType: "PersistError"
        )
        #expect(event.result == .failed)
        #expect(event.errorType == "PersistError")
        #expect(event.reason == "count=2")
    }
}
