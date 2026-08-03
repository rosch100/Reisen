import Foundation
import SwiftData

@Model
public final class SDGap {
    public var id: UUID = UUID()
    public var tripStartAt: Date?
    public var tripEndAt: Date?
    public var trip: SDTrip?
    public var gapStart: Date = Date(timeIntervalSince1970: 0)
    public var gapEnd: Date = Date(timeIntervalSince1970: 0)
    public var kindRaw: String = ""
    public var fromBooking: SDBooking?
    public var toBooking: SDBooking?
    public var titleOverride: String?
    public var identityKey: String?
    public var priceAmount: Double?
    public var priceCurrencyCode: String?
    public var suggestionStateRaw: String = "none"

    public init(
        id: UUID = UUID(),
        trip: SDTrip? = nil,
        fromBooking: SDBooking? = nil,
        toBooking: SDBooking? = nil,
        gapStart: Date,
        gapEnd: Date,
        kindRaw: String,
        titleOverride: String? = nil,
        identityKey: String? = nil,
        priceAmount: Double? = nil,
        priceCurrencyCode: String? = nil,
        suggestionStateRaw: String = "none"
    ) {
        self.id = id
        self.trip = trip
        self.fromBooking = fromBooking
        self.toBooking = toBooking
        self.gapStart = gapStart
        self.gapEnd = gapEnd
        self.kindRaw = kindRaw
        self.titleOverride = titleOverride
        self.identityKey = identityKey
        self.priceAmount = priceAmount
        self.priceCurrencyCode = priceCurrencyCode
        self.suggestionStateRaw = suggestionStateRaw
    }
}
