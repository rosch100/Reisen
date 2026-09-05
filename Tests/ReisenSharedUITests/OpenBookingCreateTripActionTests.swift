import Foundation
import SwiftData
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

private let day: TimeInterval = 24 * 60 * 60
private let hour: TimeInterval = 60 * 60
private let now = Date(timeIntervalSince1970: 1_700_000_000)
private let upcomingStart = now.addingTimeInterval(day)
private let pastStart = now.addingTimeInterval(-10 * day)

@MainActor
private func insertBooking(
    id: UUID = UUID(),
    provider: ProviderID,
    type: BookingType,
    title: String,
    startAt: Date,
    duration: TimeInterval = day,
    into context: ModelContext
) -> SDBooking {
    let booking = SDBooking(
        id: id,
        providerRaw: provider.rawValue,
        bookingTypeRaw: type.rawValue,
        title: title,
        startAt: startAt,
        endAt: startAt.addingTimeInterval(duration),
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(booking)
    return booking
}

@MainActor
@Test func openBookingCreateTripAction_seedStoresSelectedBookingIDs() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let selectedID = UUID()
    let otherID = UUID()

    let selected = insertBooking(
        id: selectedID,
        provider: .check24,
        type: .hotel,
        title: "Selected",
        startAt: upcomingStart,
        into: context
    )
    let other = insertBooking(
        id: otherID,
        provider: .check24,
        type: .hotel,
        title: "Other",
        startAt: upcomingStart,
        into: context
    )

    let seed = try #require(
        OpenBookingCreateTripAction.seed(
            fromIDs: [selectedID],
            in: [selected, other],
            now: now
        )
    )
    #expect(seed.bookingIDs == [selectedID])
}

@MainActor
@Test func openBookingCreateTripAction_fromAllUsesUpcomingOnly() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let past = insertBooking(
        provider: .manual,
        type: .activity,
        title: "Past",
        startAt: pastStart,
        duration: hour,
        into: context
    )
    let upcoming = insertBooking(
        provider: .manual,
        type: .activity,
        title: "Upcoming",
        startAt: upcomingStart,
        into: context
    )

    let seed = try #require(OpenBookingCreateTripAction.seed(from: [past, upcoming], now: now))
    #expect(seed.bookingIDs == [upcoming.id])
    #expect(OpenBookingCreateTripAction.seed(from: [past], now: now) == nil)
}

@MainActor
@Test func openBookingCreateTripAction_seedFromIDsKeepsPastManual() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let pastID = UUID()
    let past = insertBooking(
        id: pastID,
        provider: .manual,
        type: .activity,
        title: "Past",
        startAt: pastStart,
        duration: hour,
        into: context
    )

    let seed = try #require(
        OpenBookingCreateTripAction.seed(fromIDs: [pastID], in: [past], now: now)
    )
    #expect(seed.bookingIDs == [pastID])
}

@Test func openBookingCreateTripAction_dateRangeTextNilWhenEmpty() {
    #expect(OpenBookingCreateTripAction.dateRangeText(for: []) == nil)
}

@MainActor
@Test("OpenBookingCreateTripAction dateRangeText Default: Hotel-GMT-Tag")
func openBookingCreateTripAction_dateRangeText_keepsHotelGMTDay() throws {
    let stay = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let booking = insertBooking(
        provider: .manual,
        type: .hotel,
        title: "Stay",
        startAt: stay,
        duration: 0,
        into: container.mainContext
    )
    let text = OpenBookingCreateTripAction.dateRangeText(for: [booking])
    #expect(text != nil)
    #expect(text?.contains("5.9") == true)
    #expect(text?.contains("4.9") != true)
}
