import Foundation
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

@MainActor
final class SpyStringPasteboard: StringPasteboard {
    private(set) var copiedValues: [String] = []

    func copy(_ string: String) {
        guard !string.isEmpty else { return }
        copiedValues.append(string)
    }
}

@MainActor
@Test func stringPasteboard_emptyStringDoesNotWrite() {
    let spy = SpyStringPasteboard()
    spy.copy("")
    #expect(spy.copiedValues.isEmpty)
}

@MainActor
@Test func stringPasteboard_nonEmptyWritesValue() {
    let spy = SpyStringPasteboard()
    spy.copy("ABC123")
    #expect(spy.copiedValues == ["ABC123"])
}

@MainActor
@Test func bookingScheduleFields_confirmationIsIdentifierCopyKind() throws {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }

    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(86_400)

    let booking = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel Berlin",
        confirmationCode: "ABC123",
        startAt: start,
        endAt: end,
        locationTo: "Berlin",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(booking)

    let fields = BookingScheduleFields.make(booking: booking)
    let confirmation = try #require(fields.first {
        $0.label == BookingDetailLabels.confirmationNumber
    })
    #expect(confirmation.copyKind == .identifier)
    #expect(confirmation.value == "ABC123")

    let location = try #require(fields.first {
        $0.label == BookingType.hotel.locationToLabel
    })
    #expect(location.copyKind == .standard)
}

@MainActor
@Test func bookingRateFields_priceIsStandardCopyKind() throws {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }

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
        totalPriceCurrency: "EUR"
    )
    context.insert(booking)

    let rate = try #require(booking.rateDetails)
    let fields = BookingRateFields.make(rate: rate, booking: booking)
    let price = try #require(fields.first { $0.label == BookingDetailLabels.price })
    #expect(price.copyKind == .standard)
}
