import Foundation

public struct PasteImportExtraction: Equatable, Sendable {
    public var bookingType: BookingType?
    public var startAt: Date?
    public var endAt: Date?
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var operatorName: String?
    public var status: BookingStatus?
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var hotelOffsetSeconds: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var passengers: [BookingPassenger]
    public var guestHints: [BookingGuestHint]
    public var rateDetails: BookingRateDetails?
    public var deadlines: [CancellationDeadline]

    public init(
        bookingType: BookingType? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        operatorName: String? = nil,
        status: BookingStatus? = nil,
        hotelCheckInMinutes: Int? = nil,
        hotelCheckOutMinutes: Int? = nil,
        hotelOffsetSeconds: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        passengers: [BookingPassenger] = [],
        guestHints: [BookingGuestHint] = [],
        rateDetails: BookingRateDetails? = nil,
        deadlines: [CancellationDeadline] = []
    ) {
        self.bookingType = bookingType
        self.startAt = startAt
        self.endAt = endAt
        self.title = title
        self.confirmationCode = confirmationCode
        self.externalUrl = externalUrl
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.locationFromAddress = locationFromAddress
        self.locationToAddress = locationToAddress
        self.operatorName = operatorName
        self.status = status
        self.hotelCheckInMinutes = hotelCheckInMinutes
        self.hotelCheckOutMinutes = hotelCheckOutMinutes
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.passengers = passengers
        self.guestHints = guestHints
        self.rateDetails = rateDetails
        self.deadlines = deadlines
    }

    /// Übernimmt nur fehlende optionale Felder aus `other` (bestehende Werte bleiben).
    public mutating func fillingGaps(from other: PasteImportExtraction) {
        bookingType = bookingType ?? other.bookingType
        startAt = startAt ?? other.startAt
        endAt = endAt ?? other.endAt
        title = title ?? other.title
        confirmationCode = confirmationCode ?? other.confirmationCode
        externalUrl = externalUrl ?? other.externalUrl
        locationFrom = locationFrom ?? other.locationFrom
        locationTo = locationTo ?? other.locationTo
        locationFromAddress = locationFromAddress ?? other.locationFromAddress
        locationToAddress = locationToAddress ?? other.locationToAddress
        operatorName = operatorName ?? other.operatorName
        status = status ?? other.status
        hotelCheckInMinutes = hotelCheckInMinutes ?? other.hotelCheckInMinutes
        hotelCheckOutMinutes = hotelCheckOutMinutes ?? other.hotelCheckOutMinutes
        hotelOffsetSeconds = hotelOffsetSeconds ?? other.hotelOffsetSeconds
        flightDepartureOffsetSeconds =
            flightDepartureOffsetSeconds ?? other.flightDepartureOffsetSeconds
        flightArrivalOffsetSeconds =
            flightArrivalOffsetSeconds ?? other.flightArrivalOffsetSeconds
        if passengers.isEmpty { passengers = other.passengers }
        if guestHints.isEmpty { guestHints = other.guestHints }
        rateDetails = rateDetails ?? other.rateDetails
        if deadlines.isEmpty { deadlines = other.deadlines }
    }
}
