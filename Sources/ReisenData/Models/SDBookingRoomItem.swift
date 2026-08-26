import Foundation
import SwiftData

@Model
public final class SDBookingRoomItem {
    public var id: UUID = UUID()
    public var rateDetails: SDBookingRateDetails?

    public var category: String?
    public var confirmationCode: String?

    public var priceAmount: Double?
    public var priceCurrency: String?

    public var guestSummary: String?
    public var externalUrl: String?

    public var sortIndex: Int?

    public init(
        id: UUID = UUID(),
        rateDetails: SDBookingRateDetails? = nil,
        category: String? = nil,
        confirmationCode: String? = nil,
        priceAmount: Double? = nil,
        priceCurrency: String? = nil,
        guestSummary: String? = nil,
        externalUrl: String? = nil,
        sortIndex: Int? = nil
    ) {
        self.id = id
        self.rateDetails = rateDetails
        self.category = category
        self.confirmationCode = confirmationCode
        self.priceAmount = priceAmount
        self.priceCurrency = priceCurrency
        self.guestSummary = guestSummary
        self.externalUrl = externalUrl
        self.sortIndex = sortIndex
    }
}
