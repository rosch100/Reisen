import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func bookingUpsertKeepsChildIdentitiesInPlace() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let repo = SwiftDataBookingRepository(modelContext: context)

    let deadlineID = UUID()
    let passengerID = UUID()
    let baggageID = UUID()
    let roomID = UUID()
    let rateID = UUID()
    let bookingID = UUID()

    let first = Booking(
        id: bookingID,
        provider: .check24,
        bookingType: .hotel,
        title: "Hotel A",
        externalUrl: "https://example.com/b1",
        cancellationUrl: "https://example.com/cancel",
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_100_000),
        status: .confirmed,
        rawPayloadFingerprint: "fp-1",
        cancellationDeadlines: [
            CancellationDeadline(
                id: deadlineID,
                deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
                policyText: "free until",
                isStrict: true,
                isFreeCancellation: true
            )
        ],
        rateDetails: BookingRateDetails(
            id: rateID,
            bookingID: bookingID,
            roomCategory: "DZ",
            boardType: .breakfastIncluded,
            roomItems: [
                BookingRoomItem(id: roomID, category: "DZ", confirmationCode: "R1", sortIndex: 0)
            ]
        ),
        passengers: [
            BookingPassenger(
                id: passengerID,
                bookingID: bookingID,
                passengerNumber: 1,
                travellerType: .adult,
                givenName: "Ada",
                familyName: "Lovelace",
                baggageAllowances: [
                    BaggageAllowance(id: baggageID, type: .checkedBag, pieceCount: 1)
                ]
            )
        ]
    )

    try repo.upsert(first)
    try repo.save()

    let storedAfterFirstUpsert = try #require(try repo.fetch(id: bookingID))
    #expect(storedAfterFirstUpsert.cancellationUrl == "https://example.com/cancel")

    let second = Booking(
        id: UUID(), // different id — match via externalUrl
        provider: .check24,
        bookingType: .hotel,
        title: "Hotel A Updated",
        externalUrl: "https://example.com/b1",
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_200_000),
        status: .confirmed,
        rawPayloadFingerprint: "fp-1",
        cancellationDeadlines: [
            CancellationDeadline(
                id: deadlineID,
                deadlineAt: Date(timeIntervalSince1970: 1_699_100_000),
                policyText: "updated",
                isStrict: false,
                isFreeCancellation: false
            )
        ],
        rateDetails: BookingRateDetails(
            id: rateID,
            bookingID: bookingID,
            roomCategory: "Suite",
            boardType: .breakfastIncluded,
            roomItems: [
                BookingRoomItem(id: roomID, category: "Suite", confirmationCode: "R1", sortIndex: 0)
            ]
        ),
        passengers: [
            BookingPassenger(
                id: passengerID,
                bookingID: bookingID,
                passengerNumber: 1,
                travellerType: .adult,
                givenName: "Ada",
                familyName: "Lovelace",
                baggageAllowances: [
                    BaggageAllowance(id: baggageID, type: .checkedBag, pieceCount: 2)
                ]
            )
        ]
    )

    try repo.upsert(second)
    try repo.save()

    let stored = try #require(try repo.fetchAll().first)
    #expect(stored.id == bookingID)
    #expect(stored.title == "Hotel A Updated")
    #expect(stored.cancellationDeadlines.count == 1)
    #expect(stored.cancellationDeadlines.first?.id == deadlineID)
    #expect(stored.cancellationDeadlines.first?.policyText == "updated")
    #expect(stored.passengers.first?.id == passengerID)
    #expect(stored.passengers.first?.baggageAllowances.first?.id == baggageID)
    #expect(stored.passengers.first?.baggageAllowances.first?.pieceCount == 2)
    #expect(stored.rateDetails?.roomItems.first?.id == roomID)
    #expect(stored.rateDetails?.roomCategory == "Suite")

    // Still a single booking row after rematch.
    #expect(try repo.fetchAll().count == 1)
}

@MainActor
@Test func bookingUpsertMatchesByFingerprintWhenURLMissing() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let repo = SwiftDataBookingRepository(modelContext: context)

    let bookingID = UUID()
    let first = Booking(
        id: bookingID,
        provider: .opodo,
        bookingType: .flight,
        title: "Flight A",
        externalUrl: nil,
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_010_000),
        status: .confirmed,
        rawPayloadFingerprint: "fp-stable-42"
    )
    try repo.upsert(first)
    try repo.save()

    let second = Booking(
        id: UUID(),
        provider: .opodo,
        bookingType: .flight,
        title: "Flight A Updated",
        externalUrl: nil,
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_020_000),
        status: .confirmed,
        rawPayloadFingerprint: "fp-stable-42"
    )
    try repo.upsert(second)
    try repo.save()

    let stored = try #require(try repo.fetchAll().first)
    #expect(stored.id == bookingID)
    #expect(stored.title == "Flight A Updated")
    #expect(try repo.fetchAll().count == 1)
}

@MainActor
@Test func bookingUpsertRematchesChildrenByContentWhenIDsChange() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let repo = SwiftDataBookingRepository(modelContext: context)

    let bookingID = UUID()
    let deadlineAt = Date(timeIntervalSince1970: 1_699_000_000)
    let first = Booking(
        id: bookingID,
        provider: .check24,
        bookingType: .hotel,
        title: "Hotel",
        externalUrl: "https://example.com/stable",
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_100_000),
        status: .confirmed,
        cancellationDeadlines: [
            CancellationDeadline(
                id: UUID(),
                deadlineAt: deadlineAt,
                policyText: "free",
                isStrict: true,
                isFreeCancellation: true,
                cancellationFeeAmount: 0
            )
        ],
        rateDetails: BookingRateDetails(
            id: UUID(),
            bookingID: bookingID,
            roomCategory: "DZ",
            boardType: .breakfastIncluded,
            roomItems: [
                BookingRoomItem(id: UUID(), category: "DZ", confirmationCode: "ROOM-1", sortIndex: 0)
            ]
        ),
        passengers: [
            BookingPassenger(
                id: UUID(),
                bookingID: bookingID,
                passengerNumber: 1,
                travellerType: .adult,
                givenName: "Ada",
                familyName: "Lovelace",
                baggageAllowances: [
                    BaggageAllowance(id: UUID(), type: .checkedBag, pieceCount: 1, airlineCode: "LH")
                ]
            )
        ]
    )
    try repo.upsert(first)
    try repo.save()

    let storedFirst = try #require(try repo.fetchAll().first)
    let deadlineID = try #require(storedFirst.cancellationDeadlines.first?.id)
    let passengerID = try #require(storedFirst.passengers.first?.id)
    let baggageID = try #require(storedFirst.passengers.first?.baggageAllowances.first?.id)
    let roomID = try #require(storedFirst.rateDetails?.roomItems.first?.id)

    let second = Booking(
        id: UUID(),
        provider: .check24,
        bookingType: .hotel,
        title: "Hotel",
        externalUrl: "https://example.com/stable",
        startAt: Date(timeIntervalSince1970: 1_700_000_000),
        endAt: Date(timeIntervalSince1970: 1_700_100_000),
        status: .confirmed,
        cancellationDeadlines: [
            CancellationDeadline(
                id: UUID(),
                deadlineAt: deadlineAt,
                policyText: "updated",
                isStrict: false,
                isFreeCancellation: false,
                cancellationFeeAmount: 0
            )
        ],
        rateDetails: BookingRateDetails(
            id: UUID(),
            bookingID: bookingID,
            roomCategory: "Suite",
            boardType: .breakfastIncluded,
            roomItems: [
                BookingRoomItem(id: UUID(), category: "Suite", confirmationCode: "ROOM-1", sortIndex: 0)
            ]
        ),
        passengers: [
            BookingPassenger(
                id: UUID(),
                bookingID: bookingID,
                passengerNumber: 1,
                travellerType: .adult,
                givenName: "Ada",
                familyName: "Lovelace",
                baggageAllowances: [
                    BaggageAllowance(id: UUID(), type: .checkedBag, pieceCount: 2, airlineCode: "LH")
                ]
            )
        ]
    )
    try repo.upsert(second)
    try repo.save()

    let stored = try #require(try repo.fetchAll().first)
    #expect(stored.id == bookingID)
    #expect(stored.cancellationDeadlines.first?.id == deadlineID)
    #expect(stored.cancellationDeadlines.first?.policyText == "updated")
    #expect(stored.passengers.first?.id == passengerID)
    #expect(stored.passengers.first?.baggageAllowances.first?.id == baggageID)
    #expect(stored.passengers.first?.baggageAllowances.first?.pieceCount == 2)
    #expect(stored.rateDetails?.roomItems.first?.id == roomID)
    #expect(stored.rateDetails?.roomCategory == "Suite")
}

@MainActor
@Test func hybridStoreKeepsLocalModelsOutOfCloudConfiguration() throws {
    #expect(ReisenSchemaV9.cloudModels.contains { $0 == SDTrip.self })
    #expect(ReisenSchemaV9.cloudModels.contains { $0 == SDBooking.self })
    #expect(ReisenSchemaV9.cloudModels.contains { $0 == SDBookingGuestHint.self })
    #expect(ReisenSchemaV9.cloudModels.contains { $0 == SDGap.self })
    #expect(!ReisenSchemaV9.cloudModels.contains { $0 == SDReminder.self })
    #expect(!ReisenSchemaV9.cloudModels.contains { $0 == SDCalendarEventLink.self })
    #expect(!ReisenSchemaV9.cloudModels.contains { $0 == SDCancellationDeadlineLink.self })
    #expect(!ReisenSchemaV9.cloudModels.contains { $0 == SDPreTravelHintLink.self })

    #expect(ReisenSchemaV9.localModels.contains { $0 == SDReminder.self })
    #expect(ReisenSchemaV9.localModels.contains { $0 == SDCalendarEventLink.self })
    #expect(ReisenSchemaV9.localModels.contains { $0 == SDCancellationDeadlineLink.self })
    #expect(ReisenSchemaV9.localModels.contains { $0 == SDPreTravelHintLink.self })

    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let trip = SDTrip(
        title: "Test",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86_400)
    )
    context.insert(trip)

    let reminder = SDReminder(
        fireAt: Date(),
        targetRaw: ReminderTarget.custom.rawValue,
        channelRaw: ReminderChannel.notification.rawValue,
        statusRaw: ReminderStatus.scheduled.rawValue,
        cancellationDeadlineID: UUID()
    )
    context.insert(reminder)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<SDTrip>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<SDReminder>()).count == 1)
}
