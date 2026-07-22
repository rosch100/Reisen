import Testing
import Foundation
import ReisenDomain

@Test func gapDetectorFindsInterBookingGap() {
    let early = Booking(
        provider: .check24,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 1_000_000),
        endAt: Date(timeIntervalSince1970: 1_100_000),
        status: .confirmed
    )
    let late = Booking(
        provider: .check24,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 1_200_000),
        endAt: Date(timeIntervalSince1970: 1_300_000),
        status: .confirmed
    )
    let gaps = GapDetector(minGap: 12 * 60 * 60).computeGaps(bookings: [early, late])
    #expect(gaps.count == 1)
}
