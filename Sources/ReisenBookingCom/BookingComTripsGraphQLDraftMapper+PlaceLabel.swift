import Foundation

extension BookingComTripsGraphQLParser {
    func placeLabel(city: String?, iata: String?) -> String? {
        switch (BookingComParsing.nonEmpty(city), BookingComParsing.nonEmpty(iata)) {
        case let (city?, iata?):
            return "\(city) (\(iata))"
        case let (city?, nil):
            return city
        case let (nil, iata?):
            return iata
        case (nil, nil):
            return nil
        }
    }
}
