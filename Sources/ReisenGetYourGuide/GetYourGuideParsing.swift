import Foundation
import ReisenDomain

enum GetYourGuideParsing {
    static func trimmedNonEmpty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func firstNonEmpty(_ values: String?...) -> String? {
        values.compactMap(trimmedNonEmpty).first
    }

    static func occupancy(_ count: Int) -> Int? {
        count > 0 ? count : nil
    }

    static func participantCount(_ participant: GYGParticipant) -> Int {
        max(0, participant.count ?? 0)
    }

    /// Katalog: fehlend/`unknown` → `.unknown`, `done` → überspringen.
    static func catalogStatus(_ raw: String?) -> BookingStatus? {
        guard let raw else { return .unknown }
        if raw.lowercased() == "done" { return nil }
        return confirmedOrCancelled(raw) ?? .unknown
    }

    /// Detail: nur bekannte Stati überschreiben.
    static func detailStatus(_ raw: String?) -> BookingStatus? {
        guard let raw else { return nil }
        return confirmedOrCancelled(raw)
    }

    static func deadlines(from policy: GYGCancellationPolicy?) -> [CancellationDeadline] {
        guard let policy else { return [] }
        guard let deadlineAt = policy.expirationDate ?? policy.policyExpirationDate else { return [] }
        let typeHaystack = [policy.type, policy.policyType]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let isFree = typeHaystack.contains("freecancellation")
            || (policy.feeValue.map { $0 == 0 } ?? false)
        return [
            CancellationDeadline(
                deadlineAt: deadlineAt,
                policyText: policy.message,
                isFreeCancellation: isFree
            ),
        ]
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
