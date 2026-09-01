import Foundation

/// Canonical booking entity (provider-agnostic).
public struct Booking: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var provider: ProviderID
    public var bookingType: BookingType
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var cancellationUrl: String?
    public var startAt: Date
    public var endAt: Date
    /// Stay-/Lokal-Offset (historischer Name; Hotel und Mietwagen-Pickup). Persistiert unter diesem Key.
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
    /// Experience-Partner / Car-Rental-Provider (SSOT Display).
    public var operatorName: String?
    /// Ganztägiges Erlebnis / All-Day-Slot (z. B. Traveloka TIME SLOT).
    public var isAllDay: Bool?
    public var status: BookingStatus
    public var lastSyncedAt: Date?
    public var rawPayloadFingerprint: String?
    public var tripID: UUID?
    public var cancellationDeadlines: [CancellationDeadline]
    public var rateDetails: BookingRateDetails?
    public var passengers: [BookingPassenger]
    public var guestHints: [BookingGuestHint]

    public init(
        id: UUID = UUID(),
        provider: ProviderID,
        bookingType: BookingType,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        cancellationUrl: String? = nil,
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
        operatorName: String? = nil,
        isAllDay: Bool? = nil,
        status: BookingStatus = .unknown,
        lastSyncedAt: Date? = nil,
        rawPayloadFingerprint: String? = nil,
        tripID: UUID? = nil,
        cancellationDeadlines: [CancellationDeadline] = [],
        rateDetails: BookingRateDetails? = nil,
        passengers: [BookingPassenger] = [],
        guestHints: [BookingGuestHint] = []
    ) {
        self.id = id
        self.provider = provider
        self.bookingType = bookingType
        self.title = title
        self.confirmationCode = confirmationCode
        self.externalUrl = externalUrl
        self.cancellationUrl = cancellationUrl
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
        self.operatorName = operatorName
        self.isAllDay = isAllDay
        self.status = status
        self.lastSyncedAt = lastSyncedAt
        self.rawPayloadFingerprint = rawPayloadFingerprint
        self.tripID = tripID
        self.cancellationDeadlines = cancellationDeadlines
        self.rateDetails = rateDetails
        self.passengers = passengers
        self.guestHints = guestHints
    }

    /// Hotel-Wall-Clock-TZ über Domain-SSOT (`HotelTimeZone`).
    public var resolvedHotelTimeZone: TimeZone {
        HotelTimeZone.resolve(
            bookingOffsetSeconds: hotelOffsetSeconds,
            deadlineOffsetSeconds: cancellationDeadlines.compactMap(\.hotelOffsetSeconds).first
        )
    }

    /// Browser-öffentliche URL (ohne `reisen://manual/…`).
    public var browserURL: URL? {
        BookingExternalURL.browserURL(from: externalUrl)
    }

    /// Browser-öffentliche Storno-URL (derselbe Filter wie `browserURL`).
    public var cancellationBrowserURL: URL? {
        BookingExternalURL.browserURL(from: cancellationUrl)
    }

    /// Policy-Mode für Storno-Portal (SSOT `(provider, bookingType)`).
    public var cancellationLinkMode: ProviderCancellationLinkMode {
        ProviderCancellationLinkPolicy.mode(provider: provider, bookingType: bookingType)
    }
}
