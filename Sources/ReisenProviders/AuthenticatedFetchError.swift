import Foundation

public enum AuthenticatedFetchError: LocalizedError, Sendable {
    case httpStatus(Int)
    case emptyBody

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "Authentifizierter Abruf fehlgeschlagen (HTTP \(code))."
        case .emptyBody:
            return "Authentifizierter Abruf lieferte keinen Text."
        }
    }
}
