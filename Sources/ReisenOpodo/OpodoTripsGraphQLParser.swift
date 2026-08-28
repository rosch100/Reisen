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
        let bookings = wrappers.compactMap { wrapper in
            wrapper.trip.flatMap(draft(from:))
        }
        return ProviderCatalog(bookings: bookings).dedupedByExternalURL().bookings
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
