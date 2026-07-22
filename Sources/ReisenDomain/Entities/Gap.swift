import Foundation

public struct Gap: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var tripID: UUID?
    public var fromBookingID: UUID?
    public var toBookingID: UUID?
    public var gapStart: Date
    public var gapEnd: Date
    public var kind: GapKind
    public var titleOverride: String?
    public var identityKey: String?
    public var priceAmount: Double?
    public var priceCurrencyCode: String?
    public var suggestionStateRaw: String

    public init(
        id: UUID = UUID(),
        tripID: UUID? = nil,
        fromBookingID: UUID? = nil,
        toBookingID: UUID? = nil,
        gapStart: Date,
        gapEnd: Date,
        kind: GapKind = .both,
        titleOverride: String? = nil,
        identityKey: String? = nil,
        priceAmount: Double? = nil,
        priceCurrencyCode: String? = nil,
        suggestionStateRaw: String = "none"
    ) {
        self.id = id
        self.tripID = tripID
        self.fromBookingID = fromBookingID
        self.toBookingID = toBookingID
        self.gapStart = gapStart
        self.gapEnd = gapEnd
        self.kind = kind
        self.titleOverride = titleOverride
        self.identityKey = identityKey
        self.priceAmount = priceAmount
        self.priceCurrencyCode = priceCurrencyCode
        self.suggestionStateRaw = suggestionStateRaw
    }
}
