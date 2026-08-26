import Foundation

extension OpodoFlightPassengersGraphQL {
    static func decodeBaggageEnvelope(json: String) throws -> OpodoFlightBaggageEnvelope {
        guard let data = json.data(using: .utf8) else { throw OpodoFlightPassengersError.invalidJSON }
        do {
            return try JSONDecoder().decode(OpodoFlightBaggageEnvelope.self, from: data)
        } catch {
            throw OpodoFlightPassengersError.invalidJSON
        }
    }
}
