import Foundation

extension OpodoTripsGraphQLParser {
    /// Für FlightTimeZoneAssigner / Deep-Links: `"Singapur (SIN)"`.
    func cityWithIata(city: String?, iata: String?) -> String? {
        let cityPart = nonEmpty(city)
        let iataPart = nonEmpty(iata)?.uppercased()
        switch (cityPart, iataPart) {
        case let (city?, iata?):
            return "\(city) (\(iata))"
        case let (city?, nil):
            return city
        case let (nil, iata?):
            return iata
        default:
            return nil
        }
    }

    func nonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
