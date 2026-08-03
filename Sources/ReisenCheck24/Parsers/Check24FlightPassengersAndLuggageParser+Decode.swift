import Foundation

extension Check24FlightPassengersAndLuggageParser {
    func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw Check24FlightPassengersAndLuggageParserDecodeError.invalidUtf8
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw Check24FlightPassengersAndLuggageParserDecodeError.decodeFailed("\(error)")
        }
    }
}
