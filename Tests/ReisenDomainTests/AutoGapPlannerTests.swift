import Testing
import Foundation
import ReisenDomain

private func booking(
    id: UUID = UUID(),
    provider: ProviderID = .manual,
    type: BookingType,
    start: TimeInterval,
    end: TimeInterval,
    status: BookingStatus = .confirmed,
    locationFrom: String? = nil,
    locationTo: String? = nil,
    autoKey: String? = nil,
    arrivalOffset: Int? = nil,
    departureOffset: Int? = nil
) -> Booking {
    Booking(
        id: id,
        provider: provider,
        bookingType: type,
        startAt: Date(timeIntervalSince1970: start),
        endAt: Date(timeIntervalSince1970: end),
        flightDepartureOffsetSeconds: departureOffset,
        flightArrivalOffsetSeconds: arrivalOffset,
        locationFrom: locationFrom,
        locationTo: locationTo,
        status: status,
        autoGapIdentityKey: autoKey
    )
}

@Test func spatial_detectsDifferentCities_withoutModeEvidence_skipsAutoTransport() {
    let a = booking(type: .hotel, start: 1_000, end: 2_000, locationTo: "Paris")
    let b = booking(type: .hotel, start: 2_000 + 3_600, end: 4_000, locationFrom: "Berlin")
    let gaps = SpatialGapDetector.detect(sortedReal: [a, b])
    #expect(gaps.isEmpty)
}

@Test func spatial_flightNeighbor_createsCappedTransportWithCities() {
    let day: TimeInterval = 24 * 60 * 60
    let a = booking(type: .hotel, start: 0, end: day, locationTo: "Paris")
    let b = booking(type: .flight, start: 5 * day, end: 5 * day + 3_600, locationFrom: "Berlin", locationTo: "FRA")
    let gaps = SpatialGapDetector.detect(sortedReal: [a, b])
    #expect(gaps.count == 1)
    #expect(gaps[0].bookingType == .flight)
    #expect(gaps[0].role == .transport)
    #expect(gaps[0].locationFrom == "Paris")
    #expect(gaps[0].locationTo == "Berlin")
    #expect(gaps[0].endAt.timeIntervalSince(gaps[0].startAt) <= SpatialGapDetector.maxTransportDuration)
}

@Test func planner_hotelPairDifferentCities_plansLodgingNotInventedTrain() {
    let day: TimeInterval = 24 * 60 * 60
    let hotelA = booking(type: .hotel, start: 0, end: day, locationFrom: "Paris", locationTo: "Paris")
    let hotelB = booking(type: .hotel, start: 5 * day, end: 6 * day, locationFrom: "Berlin", locationTo: "Berlin")
    let plan = AutoGapPlanner.plan(
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 7 * day),
        bookings: [hotelA, hotelB]
    )
    #expect(plan.contains { $0.role == .lodging && $0.bookingType == .hotel })
    #expect(!plan.contains { $0.bookingType == .train })
    let lodging = plan.filter { $0.role == .lodging }
    #expect(lodging.count == 1)
    #expect(lodging[0].endAt.timeIntervalSince(lodging[0].startAt) >= GapDetector.defaultMinGap)
}

@Test func gapDetector_hotelPairDifferentCities_splitsTransportAndLodging() {
    let day: TimeInterval = 24 * 60 * 60
    let hotelA = booking(type: .hotel, start: 0, end: day, locationFrom: "Paris", locationTo: "Paris")
    let hotelB = booking(type: .hotel, start: 5 * day, end: 6 * day, locationFrom: "Berlin", locationTo: "Berlin")
    let gaps = GapDetector().computeGaps(
        bookings: [hotelA, hotelB],
        tripStart: Date(timeIntervalSince1970: 0),
        tripEnd: Date(timeIntervalSince1970: 7 * day)
    ).filter { !$0.isTripBoundary }
    let transport = gaps.filter { $0.kind == .transport }
    let lodging = gaps.filter { $0.kind == .lodging }
    #expect(transport.count == 1)
    #expect(lodging.count == 1)
    guard let transportGap = transport.first, let lodgingGap = lodging.first else { return }
    #expect(transportGap.gapEnd.timeIntervalSince(transportGap.gapStart) <= SpatialGapDetector.maxTransportDuration)
    #expect(transportGap.gapStart == hotelA.endAt)
    #expect(lodgingGap.gapStart == transportGap.gapEnd)
    #expect(lodgingGap.gapEnd == hotelB.startAt)
}

@Test func spatial_skipsWhenEitherPlaceMissing() {
    let a = booking(type: .hotel, start: 1_000, end: 2_000, locationTo: "Paris")
    let b = booking(type: .hotel, start: 3_000, end: 4_000)
    #expect(SpatialGapDetector.detect(sortedReal: [a, b]).isEmpty)
}

@Test func planner_createsHotelForLongTemporalLodgingBetweenFlights() {
    let flightOut = booking(type: .flight, start: 1_000_000, end: 1_100_000, locationFrom: "FRA", locationTo: "BCN")
    let cancelledHotel = booking(
        type: .hotel,
        start: 1_200_000,
        end: 1_500_000,
        status: .cancelled,
        locationFrom: "Barcelona"
    )
    let flightBack = booking(type: .flight, start: 1_700_000, end: 1_800_000, locationFrom: "BCN", locationTo: "FRA")
    // Gap between flights: 1_100_000 → 1_700_000 = 600_000s ≈ 166h > 12h; classifier lodging
    let plan = AutoGapPlanner.plan(
        tripStart: Date(timeIntervalSince1970: 1_000_000),
        tripEnd: Date(timeIntervalSince1970: 1_900_000),
        bookings: [flightOut, cancelledHotel, flightBack]
    )
    let lodging = plan.filter { $0.role == .lodging }
    #expect(lodging.count == 1)
    #expect(lodging[0].bookingType == .hotel)
}

@Test func planner_ignoresAutoGapBookingsAsInput() {
    let early = booking(type: .flight, start: 1_000_000, end: 1_100_000, locationFrom: "FRA", locationTo: "MAD")
    let late = booking(type: .flight, start: 1_700_000, end: 1_800_000, locationFrom: "MAD", locationTo: "FRA")
    let filler = booking(
        provider: .autoGap,
        type: .hotel,
        start: 1_100_000,
        end: 1_700_000,
        locationFrom: "Madrid",
        autoKey: AutoGapIdentity.key(from: early.id, to: late.id, role: .lodging)
    )
    let plan = AutoGapPlanner.plan(
        tripStart: Date(timeIntervalSince1970: 900_000),
        tripEnd: Date(timeIntervalSince1970: 1_900_000),
        bookings: [early, filler, late]
    )
    #expect(plan.contains { $0.role == .lodging })
}

@Test func reconcile_updatesSameIdentityWhenTimesChange() {
    let fromID = UUID()
    let toID = UUID()
    let key = AutoGapIdentity.key(from: fromID, to: toID, role: .lodging)
    let existing = booking(
        id: UUID(),
        provider: .autoGap,
        type: .hotel,
        start: 100,
        end: 200,
        autoKey: key
    )
    let desired = AutoGapDesired(
        identityKey: key,
        role: .lodging,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 150),
        endAt: Date(timeIntervalSince1970: 250),
        fromBookingID: fromID,
        toBookingID: toID
    )
    let diff = AutoGapReconcileDiff.compute(
        desired: [desired],
        existingAuto: [existing],
        suppressedKeys: []
    )
    #expect(diff.upserts.count == 1)
    #expect(diff.upserts[0].startAt.timeIntervalSince1970 == 150)
    #expect(diff.deleteIDs.isEmpty)
}

@Test func reconcile_skipsSuppressedAndDeletesOrphan() {
    let key = "x|y|lodging"
    let orphan = booking(provider: .autoGap, type: .hotel, start: 1, end: 2, autoKey: "old|key|lodging")
    let manual = booking(provider: .manual, type: .hotel, start: 1, end: 2)
    let desired = AutoGapDesired(
        identityKey: key,
        role: .lodging,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 10),
        endAt: Date(timeIntervalSince1970: 20),
        fromBookingID: UUID(),
        toBookingID: UUID()
    )
    let diff = AutoGapReconcileDiff.compute(
        desired: [desired],
        existingAuto: [orphan],
        suppressedKeys: [key]
    )
    #expect(diff.skippedSuppressed == 1)
    #expect(diff.upserts.isEmpty)
    #expect(diff.deleteIDs == [orphan.id])
    #expect(!diff.deleteIDs.contains(manual.id))
}
