import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func bookingOperatorNameAndIsAllDayRoundTrip() throws {
    // Contract: neue optionale SDBooking-Attribute auf ReisenSchemaV7 via Lightweight-Migration.
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let repo = SwiftDataBookingRepository(modelContext: context)

    let booking = Booking(
        id: UUID(),
        provider: .traveloka,
        bookingType: .activity,
        title: "Experience Roundtrip",
        externalUrl: "https://www.traveloka.com/en-en/item/details/1?type=EXPERIENCE&id=2",
        startAt: Date(timeIntervalSince1970: 1_800_000_000),
        endAt: Date(timeIntervalSince1970: 1_800_086_400),
        operatorName: "AXES",
        isAllDay: true,
        status: .confirmed,
        rawPayloadFingerprint: "traveloka-roundtrip-1"
    )

    try repo.upsert(booking)
    try repo.save()

    let stored = try #require(try repo.fetchAll().first)
    #expect(stored.operatorName == "AXES")
    #expect(stored.isAllDay == true)

    let updated = Booking(
        id: UUID(),
        provider: .traveloka,
        bookingType: .activity,
        title: "Experience Roundtrip Updated",
        externalUrl: booking.externalUrl,
        startAt: booking.startAt,
        endAt: booking.endAt,
        operatorName: "Partner B",
        isAllDay: false,
        status: .confirmed,
        rawPayloadFingerprint: "traveloka-roundtrip-2"
    )
    try repo.upsert(updated)
    try repo.save()

    let afterUpdate = try #require(try repo.fetchAll().first)
    #expect(afterUpdate.id == stored.id)
    #expect(afterUpdate.operatorName == "Partner B")
    #expect(afterUpdate.isAllDay == false)
}
