import Foundation
import ReisenDomain

public struct ParsedBookingDetails {
    public let rawDetailsFingerprint: String?

    // Common (hotel + flights)
    public let totalPriceAmount: Double?
    public let totalPriceCurrency: String?

    // Hotel
    public let roomCategory: String?
    public let boardTypeRaw: String?
    public let includedBreakfast: Bool?
    public let guestCount: Int?
    public let roomCount: Int?

    // Flights/Fähren (optional)
    public let airline: String?
    public let passengerCount: Int?
    public let baggageInfoRaw: String?

    public init(
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
        baggageInfoRaw: String? = nil
    ) {
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
    }

    init(rateDetails: BookingRateDetails) {
        self.init(
            rawDetailsFingerprint: rateDetails.rawDetailsFingerprint,
            totalPriceAmount: rateDetails.totalPriceAmount,
            totalPriceCurrency: rateDetails.totalPriceCurrency,
            roomCategory: rateDetails.roomCategory,
            boardTypeRaw: rateDetails.boardType == .unknown ? nil : rateDetails.boardType.rawValue,
            includedBreakfast: rateDetails.includedBreakfast,
            guestCount: rateDetails.guestCount,
            roomCount: rateDetails.roomCount,
            airline: rateDetails.airline,
            passengerCount: rateDetails.passengerCount,
            baggageInfoRaw: rateDetails.baggageInfoRaw
        )
    }
}
