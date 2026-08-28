import Foundation

/// Kanonische Fakten nach Provider-Extract, vor Draft-Assembly.
public struct ProviderBookingFacts: Equatable, Sendable {
    public var provider: ProviderID
    public var bookingType: BookingType
    public var start: TemporalFact?
    public var end: TemporalFact?
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var operatorName: String?
    public var isAllDay: Bool?
    public var statusRaw: String?
    public var deadlines: [CancellationDeadline]
    public var rateDetails: BookingRateDetails?
    public var hotelOffsetSeconds: Int?
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var rawPayloadFingerprint: String?
    public var passengers: [BookingPassenger]
    public var guestHints: [BookingGuestHint]

    public init(
        provider: ProviderID,
        bookingType: BookingType,
        start: TemporalFact? = nil,
        end: TemporalFact? = nil,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        operatorName: String? = nil,
        isAllDay: Bool? = nil,
        statusRaw: String? = nil,
        deadlines: [CancellationDeadline] = [],
        rateDetails: BookingRateDetails? = nil,
        hotelOffsetSeconds: Int? = nil,
        hotelCheckInMinutes: Int? = nil,
        hotelCheckOutMinutes: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        rawPayloadFingerprint: String? = nil,
        passengers: [BookingPassenger] = [],
        guestHints: [BookingGuestHint] = []
    ) {
        self.provider = provider
        self.bookingType = bookingType
        self.start = start
        self.end = end
        self.title = title
        self.confirmationCode = confirmationCode
        self.externalUrl = externalUrl
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.locationFromAddress = locationFromAddress
        self.locationToAddress = locationToAddress
        self.operatorName = operatorName
        self.isAllDay = isAllDay
        self.statusRaw = statusRaw
        self.deadlines = deadlines
        self.rateDetails = rateDetails
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.hotelCheckInMinutes = hotelCheckInMinutes
        self.hotelCheckOutMinutes = hotelCheckOutMinutes
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.rawPayloadFingerprint = rawPayloadFingerprint
        self.passengers = passengers
        self.guestHints = guestHints
    }
}
