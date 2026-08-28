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

@Test func bookingScheduleRangeText_includesTimeForFlightLikeTypes() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(7_200)
    let train = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.train.rawValue,
        title: "ICE",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    let hotel = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    let trainText = BookingScheduleRangeText.make(for: train)
    let hotelText = BookingScheduleRangeText.make(for: hotel)
    #expect(trainText != hotelText)
    #expect(trainText.contains(":"))
}

@Test func bookingType_systemImageName_nonEmptyForAllCases() {
    for type in BookingType.allCases {
        #expect(!type.systemImageName.isEmpty)
    }
    #expect(BookingType.train.systemImageName == "train.side.front.car")
}

@Test func bookingPresentationTitle_prefersTitleThenLocalizedType() {
    let withTitle = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.train.rawValue,
        title: "ICE 123",
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2),
        statusRaw: BookingStatus.confirmed.rawValue
    )
    let withoutTitle = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.train.rawValue,
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2),
        statusRaw: BookingStatus.confirmed.rawValue
    )
    #expect(withTitle.presentationTitle == "ICE 123")
    #expect(withoutTitle.presentationTitle == withoutTitle.bookingType.displayLabel)
    #expect(withoutTitle.displayTitle == BookingType.train.defaultDisplayTitle)
}

@Test func bookingScheduleRangeText_usesDepartureArrivalOrtszeit() throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(7_200)
    let booking = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        title: "LH",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue,
        flightDepartureOffsetSeconds: 3600,
        flightArrivalOffsetSeconds: 7200
    )
    let departureTZ = try #require(TimeZone(secondsFromGMT: 3600))
    let arrivalTZ = try #require(TimeZone(secondsFromGMT: 7200))
    let expectedStart = Formatting.formatOrtszeit(
        start,
        dateFormat: "d.M. HH:mm",
        timeZone: departureTZ
    )
    let expectedEnd = Formatting.formatOrtszeit(
        end,
        dateFormat: "d.M. HH:mm",
        timeZone: arrivalTZ
    )
    #expect(BookingScheduleRangeText.make(for: booking) == "\(expectedStart) – \(expectedEnd)")
}

@Test func bookingScheduleRangeText_trainUsesStoredOffsetsNotDeviceTimeZone() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = start.addingTimeInterval(14_400)
    let jakarta = try #require(TimeZone(identifier: "Asia/Jakarta"))
    let departureOffset = jakarta.secondsFromGMT(for: start)
    let arrivalOffset = jakarta.secondsFromGMT(for: end)
    let booking = SDBooking(
        providerRaw: ProviderID.traveloka.rawValue,
        bookingTypeRaw: BookingType.train.rawValue,
        title: "Argo Bromo",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue,
        flightDepartureOffsetSeconds: departureOffset,
        flightArrivalOffsetSeconds: arrivalOffset
    )
    let withoutOffsets = SDBooking(
        providerRaw: ProviderID.traveloka.rawValue,
        bookingTypeRaw: BookingType.train.rawValue,
        title: "Argo Bromo",
        startAt: start,
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    let departureTZ = try #require(TimeZone(secondsFromGMT: departureOffset))
    let arrivalTZ = try #require(TimeZone(secondsFromGMT: arrivalOffset))
    let expectedStart = Formatting.formatOrtszeit(
        start,
        dateFormat: "d.M. HH:mm",
        timeZone: departureTZ
    )
    let expectedEnd = Formatting.formatOrtszeit(
        end,
        dateFormat: "d.M. HH:mm",
        timeZone: arrivalTZ
    )
    #expect(BookingScheduleRangeText.make(for: booking) == "\(expectedStart) – \(expectedEnd)")
    if TimeZone.current.secondsFromGMT(for: start) != departureOffset {
        #expect(BookingScheduleRangeText.make(for: booking) != BookingScheduleRangeText.make(for: withoutOffsets))
    }
}

@MainActor
@Test func bookingScheduleFields_train_usesStationAndDepartureLabels() throws {
    L10n.locale = germanLocale
    defer { L10n.locale = .current }

    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(7_200)

    let booking = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.train.rawValue,
        title: "ICE 123",
        startAt: start,
        endAt: end,
        locationFrom: "Berlin Hbf",
        locationTo: "München Hbf",
        operatorName: "DB",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    booking.rateDetails = SDBookingRateDetails(roomCategory: "1. Klasse")
    context.insert(booking)

    let fields = BookingScheduleFields.make(booking: booking)
    let labels = fields.map { $0.label }

    #expect(labels.contains(L10n.string(.bookingFieldLocationFromTrain)))
    #expect(labels.contains(L10n.string(.bookingFieldLocationToTrain)))
    #expect(labels.contains(L10n.string(.bookingFieldScheduleStartTrain)))
    #expect(labels.contains(L10n.string(.bookingFieldScheduleEndTrain)))
    #expect(labels.contains(L10n.string(.bookingFieldOperatorTrain)))
    #expect(!labels.contains(L10n.string(.bookingFieldScheduleStartHotel)))
}

@MainActor
@Test func bookingEditor_keepsOperatorNameForFerryAndOther() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(7_200)

    let ferry = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.ferry.rawValue,
        title: "Fähre Kiel",
        startAt: start,
        endAt: end,
        operatorName: "Stena Line",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(ferry)
    let ferryDraft = BookingEditorDraft.fromExisting(ferry)
    try ferryDraft.apply(to: ferry, in: context)
    #expect(ferry.operatorName == "Stena Line")

    let other = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.other.rawValue,
        title: "Transfer",
        startAt: start,
        endAt: end,
        operatorName: "Partner",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(other)
    let otherDraft = BookingEditorDraft.fromExisting(other)
    try otherDraft.apply(to: other, in: context)
    #expect(other.operatorName == "Partner")

    let flight = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        title: "LH 400",
        startAt: start,
        endAt: end,
        operatorName: "Stale",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(flight)
    let flightDraft = BookingEditorDraft.fromExisting(flight)
    try flightDraft.apply(to: flight, in: context)
    #expect(flight.operatorName == nil)
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
