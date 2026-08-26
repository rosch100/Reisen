import Foundation

public enum Check24ProviderError: LocalizedError, Sendable {
    case sessionNotEstablished
    case activitiesFetchFailed(String)
    case noBookingsFound
    case snapshotFailed
    case navigationFailed
    case invalidSessionType

    public var errorDescription: String? {
        switch self {
        case .sessionNotEstablished:
            return "Es besteht noch keine Check24 Session. Bitte zunächst anmelden."
        case .activitiesFetchFailed(let detail):
            return "Activities-API konnte nicht geladen werden: \(detail)"
        case .noBookingsFound:
            return "Keine Buchungen gefunden."
        case .snapshotFailed:
            return "Snapshot konnte nicht erstellt werden."
        case .navigationFailed:
            return "Navigation in der Check24-Webansicht ist fehlgeschlagen."
        case .invalidSessionType:
            return "Ungültige Provider-Session für Check24."
        }
    }
}
