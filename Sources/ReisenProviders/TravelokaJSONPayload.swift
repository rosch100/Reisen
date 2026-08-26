import Foundation

/// SSOT für Traveloka-API-POST-JSON (whoami, itineraries, …).
public enum TravelokaJSONPayload {
    public enum EncodingError: Error, Sendable {
        case invalidObject
        case serializationFailed
    }

    public static func encode(_ payload: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw EncodingError.invalidObject
        }
        do {
            return try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw EncodingError.serializationFailed
        }
    }
}
