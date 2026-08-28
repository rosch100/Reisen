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

public enum OpodoTripCancellationGraphQLParserError: LocalizedError, Sendable {
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Opodo Trip-Storno GraphQL konnte nicht gelesen werden."
        }
    }
}
