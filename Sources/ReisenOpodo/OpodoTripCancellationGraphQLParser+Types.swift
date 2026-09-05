import Foundation
import ReisenDomain

public struct OpodoTripCancellationParseResult: Equatable, Sendable {
    public var deadlines: [CancellationDeadline]
    public var statusRaw: String?

    public init(deadlines: [CancellationDeadline], statusRaw: String?) {
        self.deadlines = deadlines
        self.statusRaw = statusRaw
    }
}

public enum OpodoTripCancellationGraphQLParserError: LocalizedError, Equatable, Sendable {
    case invalidJSON
    case notLoggedIn
    case graphQLErrors(String?)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Opodo Trip-Storno GraphQL konnte nicht gelesen werden."
        case .notLoggedIn:
            return OpodoProviderError.sessionNotEstablished.errorDescription
        case .graphQLErrors(let message):
            if let message, !message.isEmpty {
                return "Opodo Trip-Storno GraphQL-Fehler: \(message)"
            }
            return "Opodo Trip-Storno GraphQL-Anfrage ist fehlgeschlagen."
        }
    }
}
