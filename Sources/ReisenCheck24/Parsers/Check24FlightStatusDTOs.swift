import Foundation

struct StatusEnvelope: Decodable {
    let httpstatuscode: Int?
    let success: Bool?
    let data: StatusData

    struct StatusData: Decodable {
        let passengers: [StatusPassenger]?
        let itinerary: StatusItinerary
    }
}

struct StatusPassenger: Decodable {
    let firstname: String?
    let surname: String?
    let type: String?
}

struct StatusItinerary: Decodable {
    let flights: [StatusFlight]
    let includedLuggageEqual: Bool?
}

struct StatusFlight: Decodable {
    let segments: [StatusSegment]?
    let includedLuggage: [IncludedLuggageItem]
}

struct StatusSegment: Decodable {
    let id: Int?
}

struct IncludedLuggageItem: Decodable {
    let type: String
    let pieces: Int
    let weightKg: Double?
}

enum Check24FlightPassengersAndLuggageParserDecodeError: LocalizedError {
    case invalidUtf8
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidUtf8:
            return "JSON konnte nicht in UTF-8 konvertiert werden."
        case .decodeFailed(let message):
            return "JSON konnte nicht decodiert werden: \(message)"
        }
    }
}
