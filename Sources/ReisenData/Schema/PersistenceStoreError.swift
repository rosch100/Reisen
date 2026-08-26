import Foundation

public enum PersistenceStoreError: LocalizedError, Sendable {
    case containerCreationFailed(String)
    case storeIncompatible(String)

    public var errorDescription: String? {
        switch self {
        case .containerCreationFailed(let detail):
            return "SwiftData-Store konnte nicht geöffnet werden: \(detail)"
        case .storeIncompatible(let detail):
            return """
            Die lokale Datenbank ist mit dem aktuellen Schema nicht kompatibel: \(detail)

            Du kannst die lokalen Store-Dateien zurücksetzen. Wenn iCloud Sync aktiv ist,
            können synchronisierte Reisen und Buchungen danach erneut vom iCloud-Konto geladen werden.
            """
        }
    }
}
