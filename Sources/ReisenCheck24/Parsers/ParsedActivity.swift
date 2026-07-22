import Foundation
import ReisenDomain

public struct ParsedBooking {
    public let type: BookingType
    public let title: String?
    public let confirmationCode: String?
    public let externalUrl: String?
    public let startAt: Date
    public let endAt: Date
    public let locationFrom: String?
    public let locationTo: String?
    public let locationFromAddress: String?
    public let locationToAddress: String?
    public let status: BookingStatus
    public let details: ParsedBookingDetails?
    /// Activities-API `payment.amount` (Zimmer-/Positionspreis, nicht zwingend Bestell-Gesamt).
    public let catalogPriceAmount: Double?
    public let catalogPriceCurrency: String?
    public let catalogRoomCount: Int?
    public let catalogRoomCategory: String?

    public init(
        type: BookingType,
        title: String?,
        confirmationCode: String?,
        externalUrl: String?,
        startAt: Date,
        endAt: Date,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        status: BookingStatus,
        details: ParsedBookingDetails? = nil,
        catalogPriceAmount: Double? = nil,
        catalogPriceCurrency: String? = nil,
        catalogRoomCount: Int? = nil,
        catalogRoomCategory: String? = nil
    ) {
        self.type = type
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
        self.details = details
        self.catalogPriceAmount = catalogPriceAmount
        self.catalogPriceCurrency = catalogPriceCurrency
        self.catalogRoomCount = catalogRoomCount
        self.catalogRoomCategory = catalogRoomCategory
    }
}

public struct ParsedCancellationDeadline {
    public let deadlineAt: Date
    public let policyText: String?
    public let isStrict: Bool
    public let isFreeCancellation: Bool
    public let hotelOffsetSeconds: Int?
    public let cancellationFeeAmount: Double?
}

public struct ParsedActivity {
    public let bookings: [ParsedBooking]
    public let cancellationDeadlines: [ParsedCancellationDeadline]
}

