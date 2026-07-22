import Foundation

/// Canonical booking entity (provider-agnostic).
public struct Booking: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var provider: ProviderID
    public var bookingType: BookingType
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
    public var status: BookingStatus
    public var lastSyncedAt: Date?
    public var rawPayloadFingerprint: String?
    public var tripID: UUID?
    public var cancellationDeadlines: [CancellationDeadline]
    public var rateDetails: BookingRateDetails?
    public var passengers: [BookingPassenger]

    public init(
        id: UUID = UUID(),
        provider: ProviderID,
        bookingType: BookingType,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        startAt: Date,
        endAt: Date,
        hotelOffsetSeconds: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        hotelCheckInMinutes: Int? = nil,
        hotelCheckOutMinutes: Int? = nil,
        timesSourceFingerprint: String? = nil,
        timesNormalized: Bool? = nil,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        status: BookingStatus = .unknown,
        lastSyncedAt: Date? = nil,
        rawPayloadFingerprint: String? = nil,
        tripID: UUID? = nil,
        cancellationDeadlines: [CancellationDeadline] = [],
        rateDetails: BookingRateDetails? = nil,
        passengers: [BookingPassenger] = []
    ) {
        self.id = id
        self.provider = provider
        self.bookingType = bookingType
        self.title = title
        self.confirmationCode = confirmationCode
        self.externalUrl = externalUrl
        self.startAt = startAt
        self.endAt = endAt
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.hotelCheckInMinutes = hotelCheckInMinutes
        self.hotelCheckOutMinutes = hotelCheckOutMinutes
        self.timesSourceFingerprint = timesSourceFingerprint
        self.timesNormalized = timesNormalized
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.locationFromAddress = locationFromAddress
        self.locationToAddress = locationToAddress
        self.status = status
        self.lastSyncedAt = lastSyncedAt
        self.rawPayloadFingerprint = rawPayloadFingerprint
        self.tripID = tripID
        self.cancellationDeadlines = cancellationDeadlines
        self.rateDetails = rateDetails
        self.passengers = passengers
    }
}
