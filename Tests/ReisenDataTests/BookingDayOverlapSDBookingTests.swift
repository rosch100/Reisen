import Foundation
import SwiftData
import Testing
import ReisenData
import ReisenDomain

@MainActor
@Test func bookingDayOverlap_sdBookings_dropsCancelledAndCountsCrossTrip() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let cal = HotelStayDate.calendar
    let d1 = cal.date(from: DateComponents(year: 2026, month: 9, day: 1))!
    let d3 = cal.date(from: DateComponents(year: 2026, month: 9, day: 3))!

    let tripA = SDTrip(title: "A", startDate: d1, endDate: d3)
    let tripB = SDTrip(title: "B", startDate: d1, endDate: d3)
    context.insert(tripA)
    context.insert(tripB)

    let activeA = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel A",
        startAt: d1,
        endAt: d3,
        locationTo: "Hotel",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: tripA
    )
    let activeB = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel B",
        startAt: d1,
        endAt: d3,
        locationTo: "Other",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: tripB
    )
    let cancelled = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Cancelled",
        startAt: d1,
        endAt: d3,
        locationTo: "Other",
        statusRaw: BookingStatus.cancelled.rawValue,
        trip: tripB
    )
    context.insert(activeA)
    context.insert(activeB)
    context.insert(cancelled)
    try context.save()

    #expect(activeA.daySpan.tripID == tripA.id)
    #expect(activeA.daySpan.bookingType == .hotel)

    let counts = BookingDayOverlap.countsByID(sdBookings: [activeA, activeB, cancelled])
    #expect(counts[activeA.id] == 1)
    #expect(counts[activeB.id] == 1)
    #expect(counts[cancelled.id] == nil)
}
