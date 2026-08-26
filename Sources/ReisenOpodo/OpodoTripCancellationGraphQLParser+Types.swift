import Foundation
import ReisenDomain

public struct OpodoTripCancellationParseResult: Equatable, Sendable {
    public var deadlines: [CancellationDeadline]
    public var status: BookingStatus?

    public init(deadlines: [CancellationDeadline], status: BookingStatus?) {
        self.deadlines = deadlines
        self.status = status
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
