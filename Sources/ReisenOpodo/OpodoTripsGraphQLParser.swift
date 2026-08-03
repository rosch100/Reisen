import Foundation
import ReisenDomain

/// Parses Opodo GraphQL `getTrips` into catalog drafts (HAR: My Trips / secure area).
public struct OpodoTripsGraphQLParser: Sendable {
    public init() {}

    public func parseTrips(from json: String) throws -> [ProviderBookingDraft] {
        guard let data = json.data(using: .utf8) else {
            throw OpodoTripsGraphQLParserError.invalidJSON
        }

        let envelope: OpodoTripsEnvelope
        do {
            envelope = try JSONDecoder().decode(OpodoTripsEnvelope.self, from: data)
        } catch {
            throw OpodoTripsGraphQLParserError.invalidJSON
        }

        let wrappers = envelope.data?.getTrips?.trips ?? []
        var bookings: [ProviderBookingDraft] = []
        for wrapper in wrappers {
            guard let trip = wrapper.trip else { continue }
            if let draft = draft(from: trip) {
                bookings.append(draft)
            }
        }

        var byURL: [String: ProviderBookingDraft] = [:]
        for booking in bookings {
            guard let url = booking.externalUrl else { continue }
            byURL[url] = booking
        }
        return Array(byURL.values).sorted { $0.startAt < $1.startAt }
    }
}

public enum OpodoTripsGraphQLParserError: LocalizedError, Sendable {
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Opodo GraphQL-Antwort konnte nicht gelesen werden."
        }
    }
}
