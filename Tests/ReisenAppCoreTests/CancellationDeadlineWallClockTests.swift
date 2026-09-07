import Foundation
import Testing
@testable import ReisenAppCore
import ReisenDomain

@Suite("CancellationDeadlineWallClock")
struct CancellationDeadlineWallClockTests {
    @Test func string_nilWhenHotelOffsetMissing() {
        let deadline = CancellationDeadline(
            deadlineAt: Date(timeIntervalSince1970: 1_700_000_000),
            isFreeCancellation: true,
            hotelOffsetSeconds: nil,
            bookingID: UUID()
        )
        #expect(CancellationDeadlineWallClock.string(for: deadline) == nil)
    }

    @Test func string_formatsWithHotelOffset() {
        let deadline = CancellationDeadline(
            deadlineAt: Date(timeIntervalSince1970: 1_700_000_000),
            isFreeCancellation: true,
            hotelOffsetSeconds: 3600,
            bookingID: UUID()
        )
        let text = CancellationDeadlineWallClock.string(for: deadline)
        #expect(text != nil)
        #expect(text?.isEmpty == false)
    }
}
