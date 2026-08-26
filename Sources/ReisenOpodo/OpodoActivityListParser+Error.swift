import Foundation
import ReisenDomain

public enum OpodoActivityListParserError: LocalizedError, Sendable {
    case noBookingsFound

    public var errorDescription: String? {
        switch self {
        case .noBookingsFound:
            return "Keine Opodo-Buchungen im HTML gefunden."
        }
    }
}
