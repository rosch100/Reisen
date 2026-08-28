import Foundation

public struct PasteImportDraft: Equatable, Sendable {
    public var bookingType: BookingType
    public var startAt: Date
    public var endAt: Date
    public var endAtIsPlaceholder: Bool
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var operatorName: String?
    public var status: BookingStatus
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
        bookingType: BookingType,
        startAt: Date,
        endAt: Date,
        endAtIsPlaceholder: Bool,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        operatorName: String? = nil,
        status: BookingStatus,
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
        self.endAtIsPlaceholder = endAtIsPlaceholder
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

    public func asProviderDraft() -> ProviderBookingDraft {
        ProviderBookingDraft(
            provider: .manual,
            bookingType: bookingType,
            title: title,
            confirmationCode: confirmationCode,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: locationFrom,
            locationTo: locationTo,
            locationFromAddress: locationFromAddress,
            locationToAddress: locationToAddress,
            operatorName: operatorName,
            status: status,
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: hotelOffsetSeconds,
            hotelCheckInMinutes: hotelCheckInMinutes,
            hotelCheckOutMinutes: hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: flightArrivalOffsetSeconds,
            passengers: passengers,
            guestHints: guestHints
        )
    }
}
