import Foundation

enum BilligerMietwagenJSON {
    static let decoder = JSONDecoder()

    static func decode<T: Decodable>(_ type: T.Type, from jsonText: String) throws -> T {
        try decoder.decode(type, from: Data(jsonText.utf8))
    }
}
