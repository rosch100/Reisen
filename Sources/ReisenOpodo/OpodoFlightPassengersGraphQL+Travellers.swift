import Foundation
import ReisenDomain

extension OpodoFlightPassengersGraphQL {
    static func parseTravellers(from json: String) throws -> [BookingPassenger] {
        let envelope = try decodeSupportAreaEnvelope(json: json)
        let dtos = envelope.data.getTripByToken.trip.travellers
        guard !dtos.isEmpty else {
            throw OpodoFlightPassengersError.noTravellers
        }

        // SupportArea doesn't provide `numPassenger`, so we derive passengerNumber by array index.
        return dtos.enumerated().map { idx, dto in
            BookingPassenger(
                passengerNumber: idx + 1,
                travellerType: TravellerType.parse(dto.travellerType),
                title: dto.title,
                givenName: dto.name,
                familyName: dto.firstLastName,
                secondFamilyName: dto.secondLastName,
                birthDate: ISODateTime.parse(dto.birthDate),
                baggageAllowances: []
            )
        }
    }

    static func decodeSupportAreaEnvelope(json: String) throws -> OpodoFlightSupportAreaEnvelope {
        guard let data = json.data(using: .utf8) else { throw OpodoFlightPassengersError.invalidJSON }
        do {
            return try JSONDecoder().decode(OpodoFlightSupportAreaEnvelope.self, from: data)
        } catch {
            throw OpodoFlightPassengersError.invalidJSON
        }
    }
}
