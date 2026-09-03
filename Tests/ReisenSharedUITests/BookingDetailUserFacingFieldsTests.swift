import Foundation
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

private let germanLocale = Locale(identifier: "de")

@MainActor
@Test func bookingRateFields_omitsInternalAndDuplicateFields() throws {
    try L10n.withLocale(germanLocale) {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(86_400)

        let booking = SDBooking(
            providerRaw: ProviderID.check24.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: "Hotel Berlin",
            startAt: start,
            endAt: end,
            statusRaw: BookingStatus.confirmed.rawValue
        )
        booking.rateDetails = SDBookingRateDetails(
            totalPriceAmount: 199.5,
            totalPriceCurrency: "EUR",
            boardTypeRaw: BookingBoardType.breakfastIncluded.rawValue,
            includedBreakfast: true,
            guestCount: 2,
            lastParsedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        context.insert(booking)

        let rate = try #require(booking.rateDetails)
        let fields = BookingRateFields.make(rate: rate, booking: booking)
        let ids = Set(fields.map(\.id))

        #expect(ids.contains("rate.price"))
        #expect(ids.contains("rate.boardType"))
        #expect(ids.contains("rate.guests"))
        #expect(!ids.contains("rate.currency"))
        #expect(!ids.contains("rate.lastParsed"))
        #expect(!ids.contains("rate.breakfast"))
    }
}

@MainActor
@Test func bookingRateFields_showsBreakfastOnlyWhenBoardTypeUnknown() throws {
    try L10n.withLocale(germanLocale) {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(86_400)

        let booking = SDBooking(
            providerRaw: ProviderID.check24.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: "Hotel Berlin",
            startAt: start,
            endAt: end,
            statusRaw: BookingStatus.confirmed.rawValue
        )
        booking.rateDetails = SDBookingRateDetails(
            totalPriceAmount: 120,
            totalPriceCurrency: "EUR",
            includedBreakfast: true
        )
        context.insert(booking)

        let rate = try #require(booking.rateDetails)
        let fields = BookingRateFields.make(rate: rate, booking: booking)
        #expect(fields.contains(where: { $0.id == "rate.breakfast" }))
        #expect(!fields.contains(where: { $0.id == "rate.boardType" }))
    }
}

@MainActor
@Test func bookingScheduleFields_showsHotelLocationToAddress() throws {
    try L10n.withLocale(germanLocale) {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(86_400)
        let address = "Johannisstr. 11, 10117 Berlin, Deutschland"

        let booking = SDBooking(
            providerRaw: ProviderID.check24.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: "Hostel Berlin",
            startAt: start,
            endAt: end,
            locationTo: "Berlin",
            locationToAddress: address,
            statusRaw: BookingStatus.confirmed.rawValue
        )
        context.insert(booking)

        let fields = BookingScheduleFields.make(booking: booking)
        let addressField = try #require(fields.first(where: { $0.id == "schedule.locationToAddress" }))
        #expect(addressField.value == address)
    }
}

@Test func bookingCancellationDeadline_hidesStrictBadgeInDetail() {
    #expect(BookingCancellationDeadlineUserFacing.showsStrictBadgeInDetail == false)
}

@Test func bookingGuestHintPresentation_omitsEditorFieldLabels() {
    #expect(BookingGuestHintPresentation.usesEditorFieldLabels == false)

    let withDetail = BookingGuestHintPresentation.make(title: "Check-in", detail: "Ab 15 Uhr")
    #expect(withDetail.title == "Check-in")
    #expect(withDetail.detail == "Ab 15 Uhr")

    let withoutDetail = BookingGuestHintPresentation.make(title: "Parken", detail: "")
    #expect(withoutDetail.detail == nil)
}
