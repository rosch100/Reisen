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
                travellerType: TravellerType(rawValue: (dto.travellerType ?? "").uppercased().lowercased())
                    ?? .unknown,
                title: dto.title,
                givenName: dto.name,
                familyName: dto.firstLastName,
                secondFamilyName: dto.secondLastName,
                birthDate: parseISODateTime(dto.birthDate),
                baggageAllowances: []
            )
        }
    }

    static func parseISODateTime(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
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
