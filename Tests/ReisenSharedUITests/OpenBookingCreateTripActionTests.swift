import Foundation
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

@MainActor
@Test func openBookingCreateTripAction_seedStoresSelectedBookingIDs() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(86_400)
    let selectedID = UUID()
    let otherID = UUID()

    let selected = SDBooking(
        id: selectedID,
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Selected",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    let other = SDBooking(
        id: otherID,
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Other",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(selected)
    context.insert(other)

    let seed = try #require(
        OpenBookingCreateTripAction.seed(fromIDs: [selectedID], in: [selected, other])
    )
    #expect(seed.bookingIDs == [selectedID])
}

@Test func openBookingCreateTripAction_dateRangeTextNilWhenEmpty() {
    #expect(OpenBookingCreateTripAction.dateRangeText(for: []) == nil)
}
