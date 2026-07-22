import Foundation

/// Draft produced by a provider before persistence (canonical domain shape).
public struct ProviderBookingDraft: Equatable, Sendable {
    public var provider: ProviderID
    public var bookingType: BookingType
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var startAt: Date
    public var endAt: Date
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var status: BookingStatus
    public var deadlines: [CancellationDeadline]
    public var rateDetails: BookingRateDetails?
    public var hotelOffsetSeconds: Int?
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var rawPayloadFingerprint: String?
    public var passengers: [BookingPassenger]

    public init(
        provider: ProviderID,
        bookingType: BookingType,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        startAt: Date,
        endAt: Date,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        status: BookingStatus = .unknown,
        deadlines: [CancellationDeadline] = [],
        rateDetails: BookingRateDetails? = nil,
        hotelOffsetSeconds: Int? = nil,
        hotelCheckInMinutes: Int? = nil,
        hotelCheckOutMinutes: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        rawPayloadFingerprint: String? = nil,
        passengers: [BookingPassenger] = []
    ) {
        self.provider = provider
        self.bookingType = bookingType
        self.title = title
        self.confirmationCode = confirmationCode
        self.externalUrl = externalUrl
        self.startAt = startAt
        self.endAt = endAt
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.locationFromAddress = locationFromAddress
        self.locationToAddress = locationToAddress
        self.status = status
        self.deadlines = deadlines
        self.rateDetails = rateDetails
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.hotelCheckInMinutes = hotelCheckInMinutes
        self.hotelCheckOutMinutes = hotelCheckOutMinutes
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.rawPayloadFingerprint = rawPayloadFingerprint
        self.passengers = passengers
    }
}

public struct ProviderCatalog: Equatable, Sendable {
    public var bookings: [ProviderBookingDraft]

    public init(bookings: [ProviderBookingDraft]) {
        self.bookings = bookings
    }
}

public struct ProviderBookingRef: Hashable, Sendable {
    public var externalUrl: String
    public var bookingType: BookingType
    /// Hotel-Ortszeit-Offset für Storno-Parsing (Booking.com Confirmation: Zeitzone der Unterkunft).
    public var hotelOffsetSeconds: Int?

    public init(
        externalUrl: String,
        bookingType: BookingType,
        hotelOffsetSeconds: Int? = nil
    ) {
        self.externalUrl = externalUrl
        self.bookingType = bookingType
        self.hotelOffsetSeconds = hotelOffsetSeconds
    }
}

public struct ProviderBookingEnrichment: Equatable, Sendable {
    public var deadlines: [CancellationDeadline]
    public var rateDetails: BookingRateDetails?
    public var passengers: [BookingPassenger]?
    public var hotelOffsetSeconds: Int?
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    /// Wenn gesetzt, überschreibt den Katalog-Status (z. B. Opodo-Storno erst im Detail sichtbar).
    public var status: BookingStatus?

    public init(
        deadlines: [CancellationDeadline] = [],
        rateDetails: BookingRateDetails? = nil,
        passengers: [BookingPassenger]? = nil,
        hotelOffsetSeconds: Int? = nil,
        hotelCheckInMinutes: Int? = nil,
        hotelCheckOutMinutes: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        status: BookingStatus? = nil
    ) {
        self.deadlines = deadlines
        self.rateDetails = rateDetails
        self.passengers = passengers
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.hotelCheckInMinutes = hotelCheckInMinutes
        self.hotelCheckOutMinutes = hotelCheckOutMinutes
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.status = status
    }
}
