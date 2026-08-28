import Foundation

/// Katalog- und Detail-I/O anhand von Status-Rohwerten (SSOT).
public enum CatalogListing {
    /// Abgeschlossen (`done` / `ended`), unabhängig von Storno.
    public static func isCompleted(_ statusRaw: String?) -> Bool {
        switch NonEmpty.string(statusRaw)?.lowercased() {
        case "done", "ended":
            return true
        default:
            return false
        }
    }

    /// Nicht in den Katalog: storniert oder abgeschlossen.
    public static func shouldDrop(_ statusRaw: String?) -> Bool {
        BookingStatus.parse(statusRaw) == .cancelled || isCompleted(statusRaw)
    }

    /// Kein Detail-Fetch bei cancelled (Katalog oder GraphQL-Enrich, z. B. Opodo HTML-Walk).
    public static func shouldFetchDetails(_ statusRaw: String?) -> Bool {
        BookingStatus.parse(statusRaw) != .cancelled
    }
}
