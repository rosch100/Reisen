import Foundation

public struct BookingRateDetails: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var bookingID: UUID?
    public var rawDetailsFingerprint: String?
    public var totalPriceAmount: Double?
    public var totalPriceCurrency: String?
    public var roomCategory: String?
    public var boardType: BookingBoardType
    public var includedBreakfast: Bool?
    public var guestCount: Int?
    public var roomCount: Int?
    public var airline: String?
    public var passengerCount: Int?
    public var baggageInfoRaw: String?
    public var roomItems: [BookingRoomItem]
    public var lastParsedAt: Date?

    public init(
        id: UUID = UUID(),
        bookingID: UUID? = nil,
        rawDetailsFingerprint: String? = nil,
        totalPriceAmount: Double? = nil,
        totalPriceCurrency: String? = nil,
        roomCategory: String? = nil,
        boardType: BookingBoardType = .unknown,
        includedBreakfast: Bool? = nil,
        guestCount: Int? = nil,
        roomCount: Int? = nil,
        airline: String? = nil,
        passengerCount: Int? = nil,
        baggageInfoRaw: String? = nil,
        roomItems: [BookingRoomItem] = [],
        lastParsedAt: Date? = nil
    ) {
        self.id = id
        self.bookingID = bookingID
        self.rawDetailsFingerprint = rawDetailsFingerprint
        self.totalPriceAmount = totalPriceAmount
        self.totalPriceCurrency = totalPriceCurrency
        self.roomCategory = roomCategory
        self.boardType = boardType
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
