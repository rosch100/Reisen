import Foundation
import Testing
import ReisenDomain

private let day: TimeInterval = 24 * 60 * 60
private let hour: TimeInterval = 60 * 60

private func booking(
    type: BookingType,
    start: TimeInterval,
    end: TimeInterval,
    status: BookingStatus = .confirmed,
    id: UUID = UUID()
) -> Booking {
    Booking(
        id: id,
        provider: .check24,
        bookingType: type,
        startAt: Date(timeIntervalSince1970: start),
        endAt: Date(timeIntervalSince1970: end),
        status: status
    )
}

@Test func tripCompleteness_emptyBookings_isNotComplete() {
    let result = TripCompletenessCalculator.evaluate(
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 7 * day),
        bookings: []
    )
    #expect(result.bookingCount == 0)
    #expect(result.interBookingGapCount == 0)
    #expect(result.edgeGapCount == 0)
    #expect(result.unknownStatusCount == 0)
    #expect(result.hasBookings == false)
    #expect(result.hasTimeGaps == false)
    #expect(result.isTimelineComplete == false)
}

@Test func tripCompleteness_twoFlightsWithInterGap_isIncomplete() {
    let early = booking(type: .flight, start: 1 * day, end: 1 * day + 3 * hour)
    let late = booking(type: .flight, start: 3 * day, end: 3 * day + 3 * hour)
    let result = TripCompletenessCalculator.evaluate(
        tripStart: Date(timeIntervalSince1970: 1 * day),
        tripEnd: Date(timeIntervalSince1970: 3 * day + 3 * hour),
        bookings: [early, late]
    )
    #expect(result.interBookingGapCount == 1)
    #expect(result.hasTimeGaps)
    #expect(result.isTimelineComplete == false)
    #expect(result.interBookingGapKinds == [.lodging])
}

@Test func tripCompleteness_hotelFillsTripWindow_isComplete() {
    let hotel = booking(type: .hotel, start: 0, end: 5 * day)
    let result = TripCompletenessCalculator.evaluate(
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 5 * day),
        bookings: [hotel]
    )
    #expect(result.isTimelineComplete)
    #expect(result.interBookingGapCount == 0)
    #expect(result.edgeGapCount == 0)
}

@Test func tripCompleteness_edgeGapsDoNotBlockCompleteness() {
    let hotel = booking(type: .hotel, start: 2 * day, end: 4 * day)
    let result = TripCompletenessCalculator.evaluate(
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 7 * day),
        bookings: [hotel]
    )
    #expect(result.isTimelineComplete)
    #expect(result.interBookingGapCount == 0)
    #expect(result.edgeGapCount >= 1)
}

@Test func tripCompleteness_cancelledBookingIgnored() {
    let hotel = booking(type: .hotel, start: 0, end: 5 * day)
    let cancelled = booking(
        type: .flight,
        start: 6 * day,
        end: 6 * day + 3 * hour,
        status: .cancelled
    )
    let result = TripCompletenessCalculator.evaluate(
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 5 * day),
        bookings: [hotel, cancelled]
    )
    #expect(result.bookingCount == 1)
    #expect(result.isTimelineComplete)
}

@Test func tripCompleteness_unknownCountsButDoesNotBlock() {
    let hotel = booking(type: .hotel, start: 0, end: 5 * day, status: .unknown)
    let result = TripCompletenessCalculator.evaluate(
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 5 * day),
        bookings: [hotel]
    )
    #expect(result.unknownStatusCount == 1)
    #expect(result.isTimelineComplete)
}

@Test func tripCompleteness_pastAndFutureBookings_noFalseInterGap() {
    // Trip läuft; vergangenes Hotel + zukünftiger Flug ohne ≥12h Lücke dazwischen.
    let pastHotel = booking(type: .hotel, start: 0, end: 3 * day)
    let futureFlight = booking(type: .flight, start: 3 * day + 2 * hour, end: 3 * day + 5 * hour)
    let result = TripCompletenessCalculator.evaluate(
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 3 * day + 5 * hour),
        bookings: [pastHotel, futureFlight]
    )
    #expect(result.interBookingGapCount == 0)
    #expect(result.isTimelineComplete)
    // Wenn fälschlich nur „ab heute“ gefiltert würde, entstünde Leading-Gap und/oder Incomplete.
}

@Test func computedGap_isTripBoundary_distinguishesLeadingAndInter() {
    let early = booking(type: .flight, start: 2 * day, end: 2 * day + 3 * hour)
    let late = booking(type: .flight, start: 4 * day, end: 4 * day + 3 * hour)
    let gaps = GapDetector().computeGaps(
        bookings: [early, late],
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 7 * day)
    )
    let leading = gaps.first { $0.gapStart.timeIntervalSince1970 == 0 }
    let inter = gaps.first { !$0.isTripBoundary }
    #expect(leading?.isTripBoundary == true)
    #expect(inter != nil)
    #expect(inter?.isTripBoundary == false)
    // Explizites Merkmal aus GapAssembly — nicht aus from/to-IDs ableiten.
    #expect(gaps.filter(\.isTripBoundary).count == 2)
    #expect(gaps.filter { !$0.isTripBoundary }.count == 1)
}
