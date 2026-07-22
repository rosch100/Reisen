import Foundation
import SwiftData
import ReisenDomain

@Model
public final class SDTrip {
    public var id: UUID
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var destination: String?
    public var notes: String?

    @Relationship(deleteRule: .nullify, inverse: \SDBooking.trip)
    public var bookings: [SDBooking]

    public init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        destination: String? = nil,
        notes: String? = nil,
        bookings: [SDBooking] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.destination = destination
        self.notes = notes
        self.bookings = bookings
    }
}

@Model
public final class SDBooking {
    public var id: UUID
    public var providerRaw: String
    public var bookingTypeRaw: String
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var startAt: Date
    public var endAt: Date
    public var hotelOffsetSeconds: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var timesSourceFingerprint: String?
    public var timesNormalized: Bool?
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var statusRaw: String
    public var lastSyncedAt: Date?
    public var rawPayloadFingerprint: String?

    public var trip: SDTrip?

    @Relationship(deleteRule: .cascade, inverse: \SDCancellationDeadline.booking)
    public var cancellationDeadlines: [SDCancellationDeadline]

    @Relationship(deleteRule: .cascade, inverse: \SDBookingRateDetails.booking)
    public var rateDetails: SDBookingRateDetails?

    @Relationship(deleteRule: .cascade, inverse: \SDBookingPassenger.booking)
    public var passengers: [SDBookingPassenger]

    public init(
        id: UUID = UUID(),
        providerRaw: String,
        bookingTypeRaw: String,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        startAt: Date,
        endAt: Date,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        statusRaw: String,
        lastSyncedAt: Date? = nil,
        rawPayloadFingerprint: String? = nil,
        trip: SDTrip? = nil,
        cancellationDeadlines: [SDCancellationDeadline] = [],
        hotelOffsetSeconds: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        hotelCheckInMinutes: Int? = nil,
        hotelCheckOutMinutes: Int? = nil,
        timesSourceFingerprint: String? = nil,
        timesNormalized: Bool? = nil,
        rateDetails: SDBookingRateDetails? = nil,
        passengers: [SDBookingPassenger] = []
    ) {
        self.id = id
        self.providerRaw = providerRaw
        self.bookingTypeRaw = bookingTypeRaw
        self.title = title
        self.confirmationCode = confirmationCode
        self.externalUrl = externalUrl
        self.startAt = startAt
        self.endAt = endAt
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.locationFromAddress = locationFromAddress
        self.locationToAddress = locationToAddress
        self.statusRaw = statusRaw
        self.lastSyncedAt = lastSyncedAt
        self.rawPayloadFingerprint = rawPayloadFingerprint
        self.trip = trip
        self.cancellationDeadlines = cancellationDeadlines
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.hotelCheckInMinutes = hotelCheckInMinutes
        self.hotelCheckOutMinutes = hotelCheckOutMinutes
        self.timesSourceFingerprint = timesSourceFingerprint
        self.timesNormalized = timesNormalized
        self.rateDetails = rateDetails
        self.passengers = passengers
    }
}

@Model
public final class SDCancellationDeadline {
    public var id: UUID
    public var deadlineAt: Date
    public var policyText: String?
    public var isStrict: Bool
    public var isFreeCancellation: Bool
    public var hotelOffsetSeconds: Int?
    public var cancellationFeeAmount: Double?

    public var booking: SDBooking?

    @Relationship(deleteRule: .cascade, inverse: \SDReminder.cancellationDeadline)
    public var reminders: [SDReminder]

    public init(
        id: UUID = UUID(),
        deadlineAt: Date,
        policyText: String? = nil,
        isStrict: Bool = true,
        isFreeCancellation: Bool = false,
        hotelOffsetSeconds: Int? = nil,
        cancellationFeeAmount: Double? = nil,
        booking: SDBooking? = nil,
        reminders: [SDReminder] = []
    ) {
        self.id = id
        self.deadlineAt = deadlineAt
        self.policyText = policyText
        self.isStrict = isStrict
        self.isFreeCancellation = isFreeCancellation
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.cancellationFeeAmount = cancellationFeeAmount
        self.booking = booking
        self.reminders = reminders
    }
}

@Model
public final class SDBookingRateDetails {
    public var id: UUID
    public var booking: SDBooking?
    public var rawDetailsFingerprint: String?
    public var totalPriceAmount: Double?
    public var totalPriceCurrency: String?
    public var roomCategory: String?
    public var boardTypeRaw: String?
    public var includedBreakfast: Bool?
    public var guestCount: Int?
    public var roomCount: Int?
    public var airline: String?
    public var passengerCount: Int?
    public var baggageInfoRaw: String?
    public var lastParsedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SDBookingRoomItem.rateDetails)
    public var roomItems: [SDBookingRoomItem]

    public init(
        id: UUID = UUID(),
        booking: SDBooking? = nil,
        rawDetailsFingerprint: String? = nil,
        totalPriceAmount: Double? = nil,
        totalPriceCurrency: String? = nil,
        roomCategory: String? = nil,
        boardTypeRaw: String? = nil,
        includedBreakfast: Bool? = nil,
        guestCount: Int? = nil,
        roomCount: Int? = nil,
        airline: String? = nil,
        passengerCount: Int? = nil,
        baggageInfoRaw: String? = nil,
        roomItems: [SDBookingRoomItem] = [],
        lastParsedAt: Date? = nil
    ) {
        self.id = id
        self.booking = booking
        self.rawDetailsFingerprint = rawDetailsFingerprint
        self.totalPriceAmount = totalPriceAmount
        self.totalPriceCurrency = totalPriceCurrency
        self.roomCategory = roomCategory
        self.boardTypeRaw = boardTypeRaw
        self.includedBreakfast = includedBreakfast
        self.guestCount = guestCount
        self.roomCount = roomCount
        self.airline = airline
        self.passengerCount = passengerCount
        self.baggageInfoRaw = baggageInfoRaw
        self.roomItems = roomItems
        self.lastParsedAt = lastParsedAt
    }
}

@Model
public final class SDBookingRoomItem {
    public var id: UUID
    public var rateDetails: SDBookingRateDetails?

    public var category: String?
    public var confirmationCode: String?

    public var priceAmount: Double?
    public var priceCurrency: String?

    public var guestSummary: String?
    public var externalUrl: String?

    public var sortIndex: Int?

    public init(
        id: UUID = UUID(),
        rateDetails: SDBookingRateDetails? = nil,
        category: String? = nil,
        confirmationCode: String? = nil,
        priceAmount: Double? = nil,
        priceCurrency: String? = nil,
        guestSummary: String? = nil,
        externalUrl: String? = nil,
        sortIndex: Int? = nil
    ) {
        self.id = id
        self.rateDetails = rateDetails
        self.category = category
        self.confirmationCode = confirmationCode
        self.priceAmount = priceAmount
        self.priceCurrency = priceCurrency
        self.guestSummary = guestSummary
        self.externalUrl = externalUrl
        self.sortIndex = sortIndex
    }
}

@Model
public final class SDBookingPassenger {
    public var id: UUID
    public var booking: SDBooking?
    public var passengerID: UUID?
    public var passengerNumber: Int
    public var travellerTypeRaw: String?

    public var title: String?
    public var givenName: String?
    public var familyName: String?
    public var secondFamilyName: String?
    public var birthDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \SDBaggageAllowance.passenger)
    public var baggageAllowances: [SDBaggageAllowance]

    public init(
        id: UUID = UUID(),
        booking: SDBooking? = nil,
        passengerID: UUID? = nil,
        passengerNumber: Int,
        travellerTypeRaw: String? = nil,
        title: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        secondFamilyName: String? = nil,
        birthDate: Date? = nil,
        baggageAllowances: [SDBaggageAllowance] = []
    ) {
        self.id = id
        self.booking = booking
        self.passengerID = passengerID
        self.passengerNumber = passengerNumber
        self.travellerTypeRaw = travellerTypeRaw
        self.title = title
        self.givenName = givenName
        self.familyName = familyName
        self.secondFamilyName = secondFamilyName
        self.birthDate = birthDate
        self.baggageAllowances = baggageAllowances
    }
}

@Model
public final class SDBaggageAllowance {
    public var id: UUID
    public var passenger: SDBookingPassenger?

    public var baggageTypeRaw: String
    public var pieceCount: Int?
    public var weightKg: Double?

    public var sectionID: String?
    public var airlineCode: String?
    public var fromLabel: String?
    public var toLabel: String?

    public init(
        id: UUID = UUID(),
        passenger: SDBookingPassenger? = nil,
        baggageTypeRaw: String,
        pieceCount: Int? = nil,
        weightKg: Double? = nil,
        sectionID: String? = nil,
        airlineCode: String? = nil,
        fromLabel: String? = nil,
        toLabel: String? = nil
    ) {
        self.id = id
        self.passenger = passenger
        self.baggageTypeRaw = baggageTypeRaw
        self.pieceCount = pieceCount
        self.weightKg = weightKg
        self.sectionID = sectionID
        self.airlineCode = airlineCode
        self.fromLabel = fromLabel
        self.toLabel = toLabel
    }
}

@Model
public final class SDGap {
    public var id: UUID
    public var tripStartAt: Date?
    public var tripEndAt: Date?
    public var trip: SDTrip?
    public var gapStart: Date
    public var gapEnd: Date
    public var kindRaw: String
    public var fromBooking: SDBooking?
    public var toBooking: SDBooking?
    public var titleOverride: String?
    public var identityKey: String?
    public var priceAmount: Double?
    public var priceCurrencyCode: String?
    public var suggestionStateRaw: String

    public init(
        id: UUID = UUID(),
        trip: SDTrip? = nil,
        fromBooking: SDBooking? = nil,
        toBooking: SDBooking? = nil,
        gapStart: Date,
        gapEnd: Date,
        kindRaw: String,
        titleOverride: String? = nil,
        identityKey: String? = nil,
        priceAmount: Double? = nil,
        priceCurrencyCode: String? = nil,
        suggestionStateRaw: String = "none"
    ) {
        self.id = id
        self.trip = trip
        self.fromBooking = fromBooking
        self.toBooking = toBooking
        self.gapStart = gapStart
        self.gapEnd = gapEnd
        self.kindRaw = kindRaw
        self.titleOverride = titleOverride
        self.identityKey = identityKey
        self.priceAmount = priceAmount
        self.priceCurrencyCode = priceCurrencyCode
        self.suggestionStateRaw = suggestionStateRaw
    }
}

@Model
public final class SDReminder {
    public var id: UUID
    public var targetRaw: String
    public var channelRaw: String
    public var statusRaw: String
    public var fireAt: Date
    public var title: String?
    public var notes: String?
    public var cancellationDeadline: SDCancellationDeadline?
    public var gap: SDGap?
    public var externalAlarmId: String?

    public init(
        id: UUID = UUID(),
        fireAt: Date,
        targetRaw: String,
        channelRaw: String,
        statusRaw: String,
        title: String? = nil,
        notes: String? = nil,
        cancellationDeadline: SDCancellationDeadline? = nil,
        gap: SDGap? = nil,
        externalAlarmId: String? = nil
    ) {
        self.id = id
        self.fireAt = fireAt
        self.targetRaw = targetRaw
        self.channelRaw = channelRaw
        self.statusRaw = statusRaw
        self.title = title
        self.notes = notes
        self.cancellationDeadline = cancellationDeadline
        self.gap = gap
        self.externalAlarmId = externalAlarmId
    }
}

@Model
public final class SDCalendarEventLink {
    public var id: UUID
    public var roleRaw: String
    public var ownerTripID: UUID
    public var ownerBookingID: UUID?

    public var eventIdentifier: String
    public var calendarItemExternalIdentifier: String?
    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        roleRaw: String,
        ownerTripID: UUID,
        ownerBookingID: UUID? = nil,
        eventIdentifier: String,
        calendarItemExternalIdentifier: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.roleRaw = roleRaw
        self.ownerTripID = ownerTripID
        self.ownerBookingID = ownerBookingID
        self.eventIdentifier = eventIdentifier
        self.calendarItemExternalIdentifier = calendarItemExternalIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}

@Model
public final class SDCancellationDeadlineLink {
    public var id: UUID
    public var ownerTripID: UUID
    public var ownerBookingID: UUID?

    public var cancellationDeadlineID: UUID
    public var leadDays: Int

    public var eventIdentifier: String
    public var reminderIdentifier: String?

    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        ownerTripID: UUID,
        ownerBookingID: UUID? = nil,
        cancellationDeadlineID: UUID,
        leadDays: Int,
        eventIdentifier: String,
        reminderIdentifier: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.ownerTripID = ownerTripID
        self.ownerBookingID = ownerBookingID
        self.cancellationDeadlineID = cancellationDeadlineID
        self.leadDays = leadDays
        self.eventIdentifier = eventIdentifier
        self.reminderIdentifier = reminderIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}
