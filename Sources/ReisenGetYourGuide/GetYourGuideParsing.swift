import Foundation
import ReisenDomain

enum GetYourGuideParsing {
    static func occupancy(of participants: [GYGParticipant]?) -> Int? {
        guard let participants, !participants.isEmpty else { return nil }
        var total = 0
        for participant in participants {
            guard let count = participantCount(participant) else { return nil }
            total += count
        }
        return occupancy(total)
    }

    /// Occupancy und Zeilen nur zusammen: unvollständige Counts → beides leer.
    static func guests(from participants: [GYGParticipant]?) -> (occupancy: Int?, passengers: [BookingPassenger]) {
        guard let participants, let occupancy = occupancy(of: participants) else {
            return (nil, [])
        }
        return (occupancy, passengers(from: participants))
    }

    static func rateDetails(
        price: GYGMoney?,
        occupancy: Int?,
        roomCategory: String? = nil
    ) -> BookingRateDetails? {
        guard price != nil || occupancy != nil else { return nil }
        return BookingRateDetails(
            totalPriceAmount: price?.amount,
            totalPriceCurrency: price?.currencyIsoCode,
            roomCategory: roomCategory,
            guestCount: occupancy
        )
    }

    private static func occupancy(_ count: Int) -> Int? {
        count > 0 ? count : nil
    }

    private static func participantCount(_ participant: GYGParticipant) -> Int? {
        guard let count = participant.count, count >= 0 else { return nil }
        return count
    }

    private static func passengers(from participants: [GYGParticipant]) -> [BookingPassenger] {
        var result: [BookingPassenger] = []
        var number = 1
        for participant in participants {
            guard let count = participantCount(participant) else { return [] }
            let type = TravellerType.parse(participant.priceCategoryLabel)
            for _ in 0..<count {
                result.append(
                    BookingPassenger(
                        passengerNumber: number,
                        travellerType: type,
                        title: participant.description
                    )
                )
                number += 1
            }
        }
        return result
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
