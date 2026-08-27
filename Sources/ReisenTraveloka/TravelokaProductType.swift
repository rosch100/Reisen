import Foundation
import ReisenDomain

enum TravelokaProductType: String, Sendable {
    case flight = "FLIGHT"
    case hotel = "HOTEL"
    case experience = "EXPERIENCE"
    case vehicleRental = "VEHICLE_RENTAL"
    case airportTransport = "SHUTTLE_AIRPORT_TRANSPORT"
    case flightAncillary = "FLIGHT_ANCILLARY"
    case insurance = "INSURANCE"
    case train = "TRAIN"
    case other

    init(raw: String?) {
        let value = (raw ?? "").uppercased()
        if let known = TravelokaProductType(rawValue: value) {
            self = known
        } else if value.contains("HOTEL") || value.contains("VILLA") || value.contains("APARTMENT") {
            self = .hotel
        } else if value.contains("FLIGHT") {
            self = .flight
        } else if value.contains("EXPERIENCE") {
            self = .experience
        } else if value.contains("VEHICLE") || value.contains("CAR") {
            self = .vehicleRental
        } else {
            self = .other
        }
    }

    var bookingType: BookingType {
        switch self {
        case .flight:
            return .flight
        case .hotel:
            return .hotel
        case .experience:
            return .activity
        case .vehicleRental:
            return .carRental
        case .airportTransport, .flightAncillary, .insurance, .train, .other:
            return .other
        }
    }
}
