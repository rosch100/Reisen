import Foundation
import ReisenDomain
import ReisenDiagnostics

/// Verpflegung und Zimmerkategorie aus dem Rate-/Offer-JSON (Objekt mit `mealType`, nicht Seiten-First-Match).
enum Check24HotelOfferFactsParser {
    struct Facts: Equatable, Sendable {
        let boardTypeRaw: String?
        let includedBreakfast: Bool?
        let roomCategory: String?
    }

    private struct OfferDTO: Decodable {
        let mealType: String?
        let mealTypeLabel: String?
        let room: RoomDTO?

        struct RoomDTO: Decodable {
            let categoryTitle: String?
        }
    }

    static func parse(from html: String) -> Facts {
        // `mealTypeLabel` ist Check24-Offer-typisch; verhindert Treffer auf fremde `mealType`-Fragmente.
        if let facts = parseOffer(from: html, containingKey: "\"mealTypeLabel\"") {
            return facts
        }
        if let facts = parseOffer(from: html, containingKey: "\"mealType\"") {
            return facts
        }
        return Facts(boardTypeRaw: nil, includedBreakfast: nil, roomCategory: nil)
    }

    private static func parseOffer(from html: String, containingKey: String) -> Facts? {
        guard let json = HotelBasketJSONScan.extractEnclosingJSONObject(
            from: html,
            containingKey: containingKey
        ),
            let data = json.data(using: .utf8)
        else {
            return nil
        }
        let dto: OfferDTO
        do {
            dto = try JSONDecoder().decode(OfferDTO.self, from: data)
        } catch {
            recordOfferDecodeSkipped(error: error)
            return nil
        }
        let board = resolveBoard(mealType: dto.mealType, mealTypeLabel: dto.mealTypeLabel)
        let roomCategory = NonEmpty.string(dto.room?.categoryTitle)
        guard board != .unknown || roomCategory != nil else { return nil }
        return Facts(
            boardTypeRaw: board == .unknown ? nil : board.rawValue,
            includedBreakfast: board.includedBreakfast,
            roomCategory: roomCategory
        )
    }

    private static func recordOfferDecodeSkipped(error: Error) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .check24,
                        operation: "check24_enrich_hotel"
                    ),
                    component: "Check24HotelOfferFactsParser",
                    phase: "offer_facts",
                    event: "offer_facts_decode_skipped",
                    result: .skipped,
                    reason: String(describing: type(of: error)),
                    visibility: .publicDiagnostic
                )
            )
        }
    }

    private static func resolveBoard(mealType: String?, mealTypeLabel: String?) -> BookingBoardType {
        let fromType = BookingBoardType.parse(mealType)
        if fromType != .unknown {
            return fromType
        }
        return BookingBoardType.parse(mealTypeLabel)
    }
}
