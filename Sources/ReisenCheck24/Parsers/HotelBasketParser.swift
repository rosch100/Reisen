import Foundation

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
        guard let basketDetailsJSON = extractTopLevelJSONObject(
            from: html,
            after: "\"basketDetails\""
        ) else {
            return nil
        }

        struct BasketDetailsDTO: Decodable {
            struct PriceDTO: Decodable {
                let amount: Double?
                let currency: String?
                let effectiveAmount: Double?
                let effectiveCurrency: String?
            }

            struct GuestDTO: Decodable {
                let firstName: String?
                let lastName: String?
            }

            struct RoomDTO: Decodable {
                let categoryTitle: String?
                let guests: [GuestDTO]?
            }

            struct PriceTotalDTO: Decodable {
                let amount: Double?
                let currency: String?
                let effectiveAmount: Double?
                let effectiveCurrency: String?
            }

            struct ItemDTO: Decodable {
                let bookingUuid: String
                let bookingNumber: String?
                let room: RoomDTO?
                let rooms: [RoomDTO]?
                let priceTotal: PriceTotalDTO?
            }

            let basketId: String
            let basketPrice: PriceDTO?
            let items: [ItemDTO]?
        }

        do {
            guard let data = basketDetailsJSON.data(using: .utf8) else { return nil }
            let dto = try JSONDecoder().decode(BasketDetailsDTO.self, from: data)
            guard let itemsDTO = dto.items, !itemsDTO.isEmpty else { return nil }

            func guestSummary(from room: BasketDetailsDTO.RoomDTO) -> String? {
                // Check24 liefert bei manchen Baskets Platzhalter `"-"` anstatt echter Namen.
                // Kanonisch darstellen: erster bekannter Name + „und N weitere Gäste“.
                let guests = room.guests ?? []
                guard !guests.isEmpty else { return nil }

                func isPlaceholder(_ s: String?) -> Bool {
                    guard let s else { return true }
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty || trimmed == "-" || trimmed == "—" || trimmed == "–"
                }

                let knownNames: [String] = guests.compactMap { guest in
                    let first = guest.firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let last = guest.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !(isPlaceholder(first) && isPlaceholder(last)) else { return nil }

                    if let first, let last,
                       !first.isEmpty, !last.isEmpty,
                       !isPlaceholder(first), !isPlaceholder(last) {
                        return "\(first) \(last)"
                    }
                    if let first, !first.isEmpty, !isPlaceholder(first) {
                        return first
                    }
                    if let last, !last.isEmpty, !isPlaceholder(last) {
                        return last
                    }
                    return nil
                }

                let placeholderCount = guests.count - knownNames.count
                if knownNames.isEmpty {
                    return nil
                }
                if placeholderCount > 0 {
                    // Nur ein bekannter Name nötig für den gewünschten Kanon.
                    if knownNames.count == 1 {
                        return "\(knownNames[0]) und \(placeholderCount) weitere Gäste"
                    }
                    return "\(knownNames.joined(separator: ", ")) und \(placeholderCount) weitere Gäste"
                }

                return knownNames.joined(separator: ", ")
            }

            // Flatten: in manchen Check24-Darstellungen stecken mehrere Zimmer in `items[...].rooms[]`.
            let items: [ParsedHotelBasketItem] = itemsDTO.enumerated().flatMap { itemIndex, item in
                let rooms: [BasketDetailsDTO.RoomDTO] = {
                    if let rooms = item.rooms, !rooms.isEmpty { return rooms }
                    if let room = item.room { return [room] }
                    return []
                }()

                guard !rooms.isEmpty else { return [ParsedHotelBasketItem]() }

                // Kein „Preis raten“: Wenn `priceTotal` mehrere Zimmer umfasst (rooms.count > 1),
                // lassen wir die Einzel-Preisfelder nil.
                let price = item.priceTotal
                let amount = (rooms.count == 1) ? (price?.effectiveAmount ?? price?.amount) : nil
                let currency = (rooms.count == 1) ? (price?.effectiveCurrency ?? price?.currency) : nil

                return rooms.enumerated().map { roomIndex, room in
                    ParsedHotelBasketItem(
                        bookingUuid: item.bookingUuid,
                        bookingNumber: item.bookingNumber,
                        roomCategoryTitle: room.categoryTitle,
                        priceTotalAmount: amount,
                        priceTotalCurrency: currency,
                        guestSummary: guestSummary(from: room),
                        sortIndex: itemIndex * 10_000 + roomIndex
                    )
                }
            }

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
            return nil
        }
    }

    /// Extracts the JSON object that immediately follows a key occurrence.
    /// Example: when `after` is `"basketDetails"`, this returns the surrounding `{ ... }`.
    private static func extractTopLevelJSONObject(from text: String, after key: String) -> String? {
        guard let keyRange = text.range(of: key) else { return nil }

        // Find the first '{' after the key.
        let searchStart = text.index(keyRange.upperBound, offsetBy: 0)
        guard let openBraceIndex = text[searchStart...].firstIndex(of: "{") else { return nil }

        guard let jsonRange = scanTopLevelJSONObjectRange(
            text: text,
            openBraceIndex: openBraceIndex
        ) else { return nil }

        return String(text[jsonRange])
    }

    private static func scanTopLevelJSONObjectRange(
        text: String,
        openBraceIndex: String.Index
    ) -> ClosedRange<String.Index>? {
        var i = openBraceIndex
        var braceDepth = 0
        var inString = false
        var isEscaped = false

        while i < text.endIndex {
            let ch = text[i]

            if inString {
                updateStringState(ch: ch, inString: &inString, isEscaped: &isEscaped)
            } else {
                let finished = updateBraceAndStringState(
                    ch: ch,
                    braceDepth: &braceDepth,
                    inString: &inString,
                    openBraceIndex: openBraceIndex,
                    currentIndex: i
                )
                if finished {
                    return openBraceIndex...i
                }
            }

            i = text.index(after: i)
        }

        return nil
    }

    private static func updateStringState(
        ch: Character,
        inString: inout Bool,
        isEscaped: inout Bool
    ) {
        if isEscaped {
            isEscaped = false
        } else if ch == "\\" {
            isEscaped = true
        } else if ch == "\"" {
            inString = false
        }
    }

    private static func updateBraceAndStringState(
        ch: Character,
        braceDepth: inout Int,
        inString: inout Bool,
        openBraceIndex: String.Index,
        currentIndex: String.Index
    ) -> Bool {
        if ch == "\"" {
            inString = true
            return false
        }

        if ch == "{" {
            braceDepth += 1
            return false
        }

        if ch == "}" {
            braceDepth -= 1
            return braceDepth == 0 && currentIndex >= openBraceIndex
        }

        return false
    }
}

