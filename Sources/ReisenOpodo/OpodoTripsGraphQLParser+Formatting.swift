import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    /// Wie Check24: Straße, PLZ+Stadt, Land — nur vorhandene Teile, keine Platzhalter.
    func hotelAddress(street: String?, postalCode: String?, city: String?, countryCode: String?) -> String? {
        let streetPart = nonEmpty(street)
        let cityPart = cityWithPostalCode(city: city, postalCode: postalCode)
        let countryPart = nonEmpty(countryCode)
        let parts = [streetPart, cityPart, countryPart].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    func cityWithPostalCode(city: String?, postalCode: String?) -> String? {
        switch (nonEmpty(city), nonEmpty(postalCode)) {
        case let (city?, zip?): return "\(zip) \(city)"
        case let (city?, nil): return city
        case let (nil, zip?): return zip
        default: return nil
        }
    }
}
