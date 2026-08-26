import Foundation
import SwiftData

@Model
public final class SDBookingRateDetails {
    public var id: UUID = UUID()
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
    public var roomItems: [SDBookingRoomItem]? = []

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

public extension SDBookingRateDetails {
    var resolvedRoomItems: [SDBookingRoomItem] { roomItems ?? [] }
}
