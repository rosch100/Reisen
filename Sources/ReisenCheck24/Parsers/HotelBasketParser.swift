import Foundation
import ReisenDomain
import ReisenDiagnostics

/// Parses Check24 hotel detail pages for the multi-room grouping basket.
///
/// In the captured HAR responses, `basketDetails` contains:
/// - `basketId`
/// - `basketPrice` (sum across items)
/// - `items[]` with `bookingUuid`, `bookingNumber`, and room info (teilweise als `room` oder als `rooms[]`),
///   plus `priceTotal` and guest info.
public enum HotelBasketParser {
    public struct ParsedHotelBasketItem: Equatable, Sendable {
        public let bookingUuid: String
        public let bookingNumber: String?
        public let roomCategoryTitle: String?
        public let priceTotalAmount: Double?
        public let priceTotalCurrency: String?
        public let guestSummary: String?
        public let sortIndex: Int?

        public init(
            bookingUuid: String,
            bookingNumber: String?,
            roomCategoryTitle: String?,
            priceTotalAmount: Double?,
            priceTotalCurrency: String?,
            guestSummary: String?,
            sortIndex: Int?
        ) {
            self.bookingUuid = bookingUuid
            self.bookingNumber = bookingNumber
            self.roomCategoryTitle = roomCategoryTitle
            self.priceTotalAmount = priceTotalAmount
            self.priceTotalCurrency = priceTotalCurrency
            self.guestSummary = guestSummary
            self.sortIndex = sortIndex
        }
    }

    public struct ParsedHotelBasket: Equatable, Sendable {
        public let basketId: String
        public let basketPriceEffectiveAmount: Double?
        public let basketPriceCurrency: String?
        public let items: [ParsedHotelBasketItem]

        public init(
            basketId: String,
            basketPriceEffectiveAmount: Double?,
            basketPriceCurrency: String?,
            items: [ParsedHotelBasketItem]
        ) {
            self.basketId = basketId
            self.basketPriceEffectiveAmount = basketPriceEffectiveAmount
            self.basketPriceCurrency = basketPriceCurrency
            self.items = items
        }
    }

    /// Best-effort parsing. Returns `nil` when no `basketDetails` JSON is present.
    public static func parse(from html: String) -> ParsedHotelBasket? {
        guard let basketDetailsJSON = HotelBasketJSONScan.extractTopLevelJSONObject(
            from: html,
            after: "\"basketDetails\""
        ) else {
            return nil
        }

        do {
            guard let data = basketDetailsJSON.data(using: .utf8) else { return nil }
            let dto = try JSONDecoder().decode(HotelBasketDetailsDTO.self, from: data)
            guard let itemsDTO = dto.items, !itemsDTO.isEmpty else { return nil }

            let items = mapItems(from: itemsDTO)

            let basketPrice = dto.basketPrice
            let basketPriceEffectiveAmount = basketPrice?.effectiveAmount ?? basketPrice?.amount
            let basketCurrency = basketPrice?.effectiveCurrency ?? basketPrice?.currency

            return ParsedHotelBasket(
                basketId: dto.basketId,
                basketPriceEffectiveAmount: basketPriceEffectiveAmount,
                basketPriceCurrency: basketCurrency,
                items: items
            )
        } catch {
            recordBasketDecodeSkipped(error: error)
            return nil
        }
    }

    private static func recordBasketDecodeSkipped(error: Error) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .check24,
                        operation: "check24_enrich_hotel"
                    ),
                    component: "HotelBasketParser",
                    phase: "basket",
                    event: "basket_decode_skipped",
                    result: .skipped,
                    reason: String(describing: type(of: error)),
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
