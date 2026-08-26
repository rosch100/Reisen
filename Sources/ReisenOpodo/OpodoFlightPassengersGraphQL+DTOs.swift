import Foundation

struct OpodoFlightSupportAreaEnvelope: Decodable {
    struct Root: Decodable {
        let getTripByToken: TripWrapper
    }
    let data: Root

    struct TripWrapper: Decodable {
        let trip: TripDTO
    }

    struct TripDTO: Decodable {
        let travellers: [TravellerDTO]
    }

    struct TravellerDTO: Decodable {
        let travellerType: String?
        let name: String?
        let title: String?
        let firstLastName: String?
        let secondLastName: String?
        let birthDate: String?
    }
}

struct OpodoFlightBaggageEnvelope: Decodable {
    struct Root: Decodable {
        let baggageInfo: BaggageInfoDTO
    }

    let data: Root

    struct BaggageInfoDTO: Decodable {
        let travellers: [BaggageTravellerDTO]?
    }

    struct BaggageTravellerDTO: Decodable {
        let numPassenger: Int?
        let sections: [BaggageSectionDTO]?
    }

    struct BaggageSectionDTO: Decodable {
        let id: String?
        let airlineCode: String?
        let baggageList: [BaggageListDTO]?
    }

    struct BaggageListDTO: Decodable {
        let type: String?
        let numPieces: Int?
        let weight: Double?
    }
}

public enum OpodoFlightPassengersError: LocalizedError, Sendable {
    case invalidJSON
    case noTravellers

    public var errorDescription: String? {
        switch self {
        case .invalidJSON: return "Opodo Flug-Passagiere/Gepäck konnte nicht gelesen werden."
        case .noTravellers: return "Opodo liefert keine Flug-Passagiere."
        }
    }
}
