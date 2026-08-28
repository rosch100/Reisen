import Foundation
import ReisenDomain

enum GetYourGuideParsing {
    static func occupancy(_ count: Int) -> Int? {
        count > 0 ? count : nil
    }

    static func participantCount(_ participant: GYGParticipant) -> Int {
        max(0, participant.count ?? 0)
    }

    /// Katalog: fehlend/`unknown` → `.unknown`, `done` → überspringen.
    /// Storno bleibt im Katalog (GYG past/upcoming), im Gegensatz zu `CatalogListing.shouldDrop`.
    static func catalogStatus(_ raw: String?) -> BookingStatus? {
        guard let raw else { return .unknown }
        if raw.lowercased() == "done" { return nil }
        return confirmedOrCancelled(raw) ?? .unknown
    }

    private static func confirmedOrCancelled(_ raw: String) -> BookingStatus? {
        switch raw.lowercased() {
        case "active":
            return .confirmed
        case "cancelled", "canceled":
            return .cancelled
        default:
            return nil
        }
    }
}

struct GYGMoney: Decodable {
    let amount: Double?
    let currencyIsoCode: String?
}

struct GYGNamedPlace: Decodable {
    let name: String?
}

struct GYGCancellationPolicy: Decodable {
    let type: String?
    let policyType: String?
    let message: String?
    let expirationDate: Date?
    let policyExpirationDate: Date?
    let feeValue: Double?
}

struct GYGParticipant: Decodable {
    let count: Int?
    let priceCategoryLabel: String?
    let description: String?
    let localizedCount: String?
}
