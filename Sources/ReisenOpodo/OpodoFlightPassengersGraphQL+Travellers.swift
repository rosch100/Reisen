import Foundation
import ReisenDomain

extension OpodoFlightPassengersGraphQL {
    static func parseTravellers(from json: String) throws -> [BookingPassenger] {
        let envelope = try OpodoGraphQLRequest.decode(
            OpodoFlightSupportAreaEnvelope.self,
            from: json,
            invalid: OpodoFlightPassengersError.invalidJSON
        )
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
                birthDate: HotelStayDate.civilDay(fromISO: dto.birthDate),
                baggageAllowances: []
            )
        }
    }
}
