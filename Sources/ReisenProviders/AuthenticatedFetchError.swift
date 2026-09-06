import Foundation

public enum AuthenticatedFetchError: LocalizedError, Sendable, Equatable {
    case httpStatus(Int)
    case emptyBody
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "Authentifizierter Abruf fehlgeschlagen (HTTP \(code))."
        case .emptyBody:
            return "Authentifizierter Abruf lieferte keinen Text."
        case .timedOut:
            return "Authentifizierter Abruf: Zeitüberschreitung."
        }
    }
}
