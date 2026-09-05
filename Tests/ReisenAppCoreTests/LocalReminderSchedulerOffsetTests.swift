import Foundation
import Testing
@testable import ReisenAppCore
import ReisenDomain

@MainActor
@Suite("LocalReminderScheduler offset eligibility")
struct LocalReminderSchedulerOffsetTests {
    @Test("deadlines without hotel offset are not free-cancellation eligible for scheduling")
    func deadlinesWithoutOffsetAreFilteredBeforeSchedule() {
        let withOffset = CancellationDeadline(
            id: UUID(),
            deadlineAt: Date(timeIntervalSince1970: 1_800_000_000),
            isStrict: true,
            isFreeCancellation: true,
            hotelOffsetSeconds: 3600,
            bookingID: UUID()
        )
        let withoutOffset = CancellationDeadline(
            id: UUID(),
            deadlineAt: Date(timeIntervalSince1970: 1_800_086_400),
            isStrict: true,
            isFreeCancellation: true,
            hotelOffsetSeconds: nil,
            bookingID: UUID()
        )
        let fee = CancellationDeadline(
            id: UUID(),
            deadlineAt: Date(timeIntervalSince1970: 1_800_172_800),
            isStrict: true,
            isFreeCancellation: false,
            hotelOffsetSeconds: 3600,
            bookingID: UUID()
        )

        let eligible = [withOffset, withoutOffset, fee].filter {
            LocalReminderScheduler.isEligibleCancellationDeadline($0)
        }
        #expect(eligible.map(\.id) == [withOffset.id])
    }
}
