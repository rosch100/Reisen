import Foundation
import ReisenDomain

/// Parses Opodo GraphQL `getTrips` into catalog drafts (HAR: My Trips / secure area).
public struct OpodoTripsGraphQLParser: Sendable {
    public init() {}

    public func parseTrips(from json: String) throws -> [ProviderBookingDraft] {
        try parseTripPage(from: json).bookings
    }

    public func parseTripPage(from json: String) throws -> OpodoGraphQLCatalog {
        let envelope = try OpodoGraphQLRequest.decode(
            OpodoTripsEnvelope.self,
            from: json,
            invalid: OpodoTripsGraphQLParserError.invalidJSON
        )
        let wrappers = envelope.data?.getTrips?.trips ?? []
        try throwIfSessionLost(envelope.errors)
        if wrappers.isEmpty {
            try throwIfGraphQLFailed(envelope.errors)
        }

        let bookings = wrappers.compactMap { wrapper in
            wrapper.trip.flatMap(draft(from:))
        }
        return OpodoGraphQLCatalog(
            bookings: bookings,
            rawTripCount: wrappers.count
        )
    }

    private static let notLoggedInErrorCode = "USER_NOT_LOGGED_IN"

    private func throwIfSessionLost(_ errors: [OpodoGraphQLError]?) throws {
        guard let errors, errors.contains(where: Self.isNotLoggedIn) else { return }
        throw OpodoTripsGraphQLParserError.notLoggedIn
    }

    private func throwIfGraphQLFailed(_ errors: [OpodoGraphQLError]?) throws {
        guard let errors, !errors.isEmpty else { return }
        let message = errors.compactMap(\.message).filter { !$0.isEmpty }.joined(separator: "; ")
        throw OpodoTripsGraphQLParserError.graphQLErrors(message.isEmpty ? nil : message)
    }

    private static func isNotLoggedIn(_ error: OpodoGraphQLError) -> Bool {
        error.extensions?.errorCode == notLoggedInErrorCode
    }
}

public enum OpodoTripsGraphQLParserError: LocalizedError, Equatable, Sendable {
    case invalidJSON
    case notLoggedIn
    case graphQLErrors(String?)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Opodo GraphQL-Antwort konnte nicht gelesen werden."
        case .notLoggedIn:
            return OpodoProviderError.sessionNotEstablished.errorDescription
        case .graphQLErrors(let message):
            if let message, !message.isEmpty {
                return "Opodo GraphQL-Fehler: \(message)"
            }
            return "Opodo GraphQL-Anfrage ist fehlgeschlagen."
        }
    }
}
