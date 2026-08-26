import Foundation
import ReisenDomain

struct FlightOrderEnvelope: Decodable {
    let cancellationOptions: FlightCancellationOptions?
    let airOrder: FlightAirOrder?
    let luggageBySegment: [[FlightLuggageByTraveller]]?
    let passengers: [FlightPassenger]?
}

struct FlightCancellationOptions: Decodable {
    let cancellable: Bool?
    let isFullRefund: Bool?
    let refundOptions: [FlightRefundOption]?
}

struct FlightRefundOption: Decodable {
    let deadlineAt: String?
    let expiresAt: String?
    let description: String?
    let isFullRefund: Bool?
    let feeAmount: Double?
}

struct FlightAirOrder: Decodable {
    let flightSegments: [FlightOrderSegment]?
}

struct FlightOrderSegment: Decodable {
    let departureTimeTz: String?
    let arrivalTimeTz: String?
    let travellerCheckedLuggage: [FlightTravellerLuggage]?
    let travellerCabinLuggage: [FlightTravellerLuggage]?
}

struct FlightTravellerLuggage: Decodable {
    let travellerReference: String?
    let luggageAllowance: FlightLuggageAllowance?
    let personalItem: Bool?
}

struct FlightLuggageByTraveller: Decodable {
    let luggageAllowance: [FlightLuggageAllowance]?
}

struct FlightLuggageAllowance: Decodable {
    let luggageType: String?
    let maxPiece: Int?
    let maxWeightPerPiece: Int?
    let massUnit: String?
}

struct FlightPassenger: Decodable {
    let travellerReference: String?
    let firstName: String?
    let lastName: String?
    let type: String?
    let gender: String?

    var travellerType: TravellerType {
        switch (type ?? "").uppercased() {
        case "ADULT": return .adult
        case "CHILD": return .child
        case "INFANT": return .infant
        default: return .unknown
        }
    }
}
