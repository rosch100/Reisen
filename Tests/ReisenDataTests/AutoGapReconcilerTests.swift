import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func autoGapReconciler_createsLodgingBetweenFlights() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let tripStart = Date(timeIntervalSince1970: 1_000_000)
    let tripEnd = Date(timeIntervalSince1970: 1_900_000)
    let trip = SDTrip(id: UUID(), title: "ES", startDate: tripStart, endDate: tripEnd)
    context.insert(trip)

    let early = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_000_000),
        endAt: Date(timeIntervalSince1970: 1_100_000),
        locationFrom: "FRA",
        locationTo: "BCN",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    let late = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_700_000),
        endAt: Date(timeIntervalSince1970: 1_800_000),
        locationFrom: "BCN",
        locationTo: "FRA",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    context.insert(early)
    context.insert(late)

    try AutoGapReconcileTrigger.run(tripIDs: [trip.id], in: context)
    try context.save()

    let autos = try context.fetch(FetchDescriptor<SDBooking>()).filter {
        $0.providerRaw == ProviderID.autoGap.rawValue
    }
    #expect(autos.count == 1)
    #expect(autos[0].bookingTypeRaw == BookingType.hotel.rawValue)
    #expect(autos[0].autoGapIdentityKey == AutoGapIdentity.key(from: early.id, to: late.id, role: .lodging))
}

@MainActor
@Test func autoGapReconciler_suppressPreventsRecreate() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let trip = SDTrip(
        id: UUID(),
        title: "ES",
        startDate: Date(timeIntervalSince1970: 1_000_000),
        endDate: Date(timeIntervalSince1970: 1_900_000)
    )
    context.insert(trip)
    let early = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_000_000),
        endAt: Date(timeIntervalSince1970: 1_100_000),
        locationFrom: "FRA",
        locationTo: "MAD",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    let late = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_700_000),
        endAt: Date(timeIntervalSince1970: 1_800_000),
        locationFrom: "MAD",
        locationTo: "FRA",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    context.insert(early)
    context.insert(late)
    let key = AutoGapIdentity.key(from: early.id, to: late.id, role: .lodging)
    try SwiftDataAutoGapReconciler.suppress(tripID: trip.id, identityKey: key, in: context)
    try AutoGapReconcileTrigger.run(tripIDs: [trip.id], in: context)
    let autos = try context.fetch(FetchDescriptor<SDBooking>()).filter {
        $0.providerRaw == ProviderID.autoGap.rawValue
    }
    #expect(autos.isEmpty)
}

@MainActor
@Test func autoGapReconciler_neverDeletesManualBooking() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let trip = SDTrip(
        id: UUID(),
        title: "ES",
        startDate: Date(timeIntervalSince1970: 1_000_000),
        endDate: Date(timeIntervalSince1970: 1_200_000)
    )
    context.insert(trip)
    let manual = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Keep me",
        startAt: Date(timeIntervalSince1970: 1_050_000),
        endAt: Date(timeIntervalSince1970: 1_150_000),
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    context.insert(manual)
    let manualID = manual.id
    try AutoGapReconcileTrigger.run(tripIDs: [trip.id], in: context)
    let found = try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == manualID }))
    #expect(found.count == 1)
    #expect(found[0].providerRaw == ProviderID.manual.rawValue)
    #expect(found[0].title == "Keep me")
}

@MainActor
@Test func assignBooking_dualTripReconcilesOldAndNew() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let tripA = SDTrip(
        id: UUID(),
        title: "A",
        startDate: Date(timeIntervalSince1970: 1_000_000),
        endDate: Date(timeIntervalSince1970: 1_900_000)
    )
    let tripB = SDTrip(
        id: UUID(),
        title: "B",
        startDate: Date(timeIntervalSince1970: 2_000_000),
        endDate: Date(timeIntervalSince1970: 2_900_000)
    )
    context.insert(tripA)
    context.insert(tripB)

    let early = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_000_000),
        endAt: Date(timeIntervalSince1970: 1_100_000),
        locationFrom: "FRA",
        locationTo: "BCN",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: tripA
    )
    let late = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_700_000),
        endAt: Date(timeIntervalSince1970: 1_800_000),
        locationFrom: "BCN",
        locationTo: "FRA",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: tripA
    )
    context.insert(early)
    context.insert(late)
    try AutoGapReconcileTrigger.run(tripIDs: [tripA.id], in: context)
    try context.save()
    #expect(try context.fetch(FetchDescriptor<SDBooking>()).filter {
        $0.providerRaw == ProviderID.autoGap.rawValue && $0.trip?.id == tripA.id
    }.count == 1)

    let tripRepo = SwiftDataTripRepository(modelContext: context)
    try tripRepo.assignBooking(bookingID: late.id, toTripID: tripB.id)
    try tripRepo.save()

    let autosOnA = try context.fetch(FetchDescriptor<SDBooking>()).filter {
        $0.providerRaw == ProviderID.autoGap.rawValue && $0.trip?.id == tripA.id
    }
    #expect(autosOnA.isEmpty)
    #expect(late.trip?.id == tripB.id)
}

@MainActor
@Test func bookingDeletion_autoGap_suppressThenNoRecreate() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let trip = SDTrip(
        id: UUID(),
        title: "ES",
        startDate: Date(timeIntervalSince1970: 1_000_000),
        endDate: Date(timeIntervalSince1970: 1_900_000)
    )
    context.insert(trip)
    let early = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_000_000),
        endAt: Date(timeIntervalSince1970: 1_100_000),
        locationFrom: "FRA",
        locationTo: "BCN",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    let late = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        startAt: Date(timeIntervalSince1970: 1_700_000),
        endAt: Date(timeIntervalSince1970: 1_800_000),
        locationFrom: "BCN",
        locationTo: "FRA",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    context.insert(early)
    context.insert(late)
    try AutoGapReconcileTrigger.run(tripIDs: [trip.id], in: context)
    try context.save()
    let auto = try #require(
        try context.fetch(FetchDescriptor<SDBooking>()).first {
            $0.providerRaw == ProviderID.autoGap.rawValue
        }
    )
    try BookingDeletion.perform(booking: auto, in: context)
    let autos = try context.fetch(FetchDescriptor<SDBooking>()).filter {
        $0.providerRaw == ProviderID.autoGap.rawValue
    }
    #expect(autos.isEmpty)
    let suppress = try context.fetch(FetchDescriptor<SDAutoGapSuppress>())
    #expect(suppress.count == 1)
}

@MainActor
@Test func domainMapper_booking_roundTripsAutoGapIdentityKey() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let key = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee|ffffffff-1111-2222-3333-444444444444|lodging"
    let model = SDBooking(
        providerRaw: ProviderID.autoGap.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2),
        statusRaw: BookingStatus.unknown.rawValue,
        autoGapIdentityKey: key
    )
    context.insert(model)
    let domain = DomainMapper.booking(from: model)
    #expect(domain.autoGapIdentityKey == key)
    #expect(domain.provider == .autoGap)

    let repo = SwiftDataBookingRepository(modelContext: context)
    try repo.upsert(domain)
    try repo.save()
    let stored = try #require(try repo.fetch(id: domain.id))
    #expect(stored.autoGapIdentityKey == key)
}

@Test func syncProviderIDs_excludeAutoGap() {
    #expect(!ProviderID.syncProviderIDs.contains(.autoGap))
    #expect(!ProviderID.syncProviderIDs.contains(.manual))
}
