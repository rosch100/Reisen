import Foundation
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

private let germanLocale = Locale(identifier: "de")

@MainActor
@Test func bookingScheduleFields_includesConfirmationIndependentOfTripAssignment() throws {
    L10n.locale = germanLocale
    defer { L10n.locale = .current }

    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(86_400)

    let openBooking = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel Berlin",
        confirmationCode: "ABC123",
        startAt: start,
        endAt: end,
        locationTo: "Berlin",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(openBooking)

    let trip = SDTrip(title: "Städtetrip", startDate: start, endDate: end)
    context.insert(trip)
    let assignedBooking = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel Berlin",
        confirmationCode: "ABC123",
        startAt: start,
        endAt: end,
        locationTo: "Berlin",
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    context.insert(assignedBooking)

    let openFields = BookingScheduleFields.make(booking: openBooking)
    let assignedFields = BookingScheduleFields.make(booking: assignedBooking)

    #expect(openFields == assignedFields)
    #expect(
        openFields.contains(where: {
            $0.label == BookingDetailLabels.confirmationNumber
                && $0.value == "ABC123"
                && $0.copyKind == .identifier
        })
    )
}

@MainActor
@Test func bookingRateFields_identicalWhetherOpenOrAssigned() throws {
    L10n.locale = germanLocale
    defer { L10n.locale = .current }

    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(86_400)

    let openBooking = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel Berlin",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    openBooking.rateDetails = SDBookingRateDetails(
        totalPriceAmount: 199.5,
        totalPriceCurrency: "EUR",
        guestCount: 2
    )
    context.insert(openBooking)

    let trip = SDTrip(title: "Städtetrip", startDate: start, endDate: end)
    context.insert(trip)
    let assignedBooking = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel Berlin",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    assignedBooking.rateDetails = SDBookingRateDetails(
        totalPriceAmount: 199.5,
        totalPriceCurrency: "EUR",
        guestCount: 2
    )
    context.insert(assignedBooking)

    let openRate = try #require(openBooking.rateDetails)
    let assignedRate = try #require(assignedBooking.rateDetails)
    #expect(
        BookingRateFields.make(rate: openRate, booking: openBooking)
            == BookingRateFields.make(rate: assignedRate, booking: assignedBooking)
    )
}
