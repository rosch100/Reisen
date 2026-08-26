import Foundation
import SwiftData

@Model
public final class SDBooking {
    public var id: UUID = UUID()
    public var providerRaw: String = ""
    public var bookingTypeRaw: String = ""
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var startAt: Date = Date(timeIntervalSince1970: 0)
    public var endAt: Date = Date(timeIntervalSince1970: 0)
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
    public var statusRaw: String = ""
    public var lastSyncedAt: Date?
    public var rawPayloadFingerprint: String?

    public var trip: SDTrip?

    @Relationship(deleteRule: .cascade, inverse: \SDCancellationDeadline.booking)
    public var cancellationDeadlines: [SDCancellationDeadline]? = []

    @Relationship(deleteRule: .cascade, inverse: \SDBookingRateDetails.booking)
    public var rateDetails: SDBookingRateDetails?

    @Relationship(deleteRule: .cascade, inverse: \SDBookingPassenger.booking)
    public var passengers: [SDBookingPassenger]? = []

    @Relationship(deleteRule: .cascade, inverse: \SDBookingGuestHint.booking)
    public var guestHints: [SDBookingGuestHint]? = []

    @Relationship(deleteRule: .nullify, inverse: \SDGap.fromBooking)
    public var gapsFrom: [SDGap]? = []

    @Relationship(deleteRule: .nullify, inverse: \SDGap.toBooking)
    public var gapsTo: [SDGap]? = []

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
        passengers: [SDBookingPassenger] = [],
        guestHints: [SDBookingGuestHint] = []
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
        self.guestHints = guestHints
    }
}
