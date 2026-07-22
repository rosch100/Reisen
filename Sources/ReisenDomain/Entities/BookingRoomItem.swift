import Foundation

/// One concrete room / position inside a provider-specific multi-room booking (e.g. Check24 basket items).
public struct BookingRoomItem: Identifiable, Equatable, Sendable {
    public var id: UUID

    /// Human readable room category / type label (e.g. "Deluxe Doppel- oder Zweibettzimmer").
    public var category: String?

    /// Booking/confirmation number of this room (provider specific).
    public var confirmationCode: String?

    /// Optional single-room price if the provider provides it.
    public var priceAmount: Double?
    public var priceCurrency: String?

    /// Optional guest summary (names/count) for UI display.
    public var guestSummary: String?

    /// Optional deep link to this room detail (provider specific).
    public var externalUrl: String?

    /// Stable ordering within the parent booking.
    public var sortIndex: Int?

    public init(
        id: UUID = UUID(),
        category: String? = nil,
        confirmationCode: String? = nil,
        priceAmount: Double? = nil,
        priceCurrency: String? = nil,
        guestSummary: String? = nil,
        externalUrl: String? = nil,
        sortIndex: Int? = nil
    ) {
        self.id = id
        self.category = category
        self.confirmationCode = confirmationCode
        self.priceAmount = priceAmount
        self.priceCurrency = priceCurrency
        self.guestSummary = guestSummary
        self.externalUrl = externalUrl
        self.sortIndex = sortIndex
    }
}

