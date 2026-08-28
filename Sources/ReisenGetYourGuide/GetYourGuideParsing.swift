import Foundation
import ReisenDomain

enum GetYourGuideParsing {
    static func occupancy(_ count: Int) -> Int? {
        count > 0 ? count : nil
    }

    static func occupancy(of participants: [GYGParticipant]?) -> Int? {
        occupancy((participants ?? []).reduce(0) { $0 + participantCount($1) })
    }

    static func participantCount(_ participant: GYGParticipant) -> Int {
        max(0, participant.count ?? 0)
    }

    /// Katalog: abgeschlossen überspringen; Storno bleibt (anders als `CatalogListing.shouldDrop`).
    static func catalogStatus(_ raw: String?) -> BookingStatus? {
        guard !CatalogListing.isCompleted(raw) else { return nil }
        return BookingStatus.parse(raw)
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
