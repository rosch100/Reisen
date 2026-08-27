import Foundation
import ReisenDomain

enum GetYourGuideJSONDecoder {
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ISODateTime.parseInstant(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Ungültiges ISO-8601-Datum: \(raw)"
            )
        }
        return decoder
    }()
}
