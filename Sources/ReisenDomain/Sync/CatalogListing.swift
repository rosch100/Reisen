import Foundation

/// Katalog- und Detail-I/O anhand von Status-Rohwerten (SSOT).
public enum CatalogListing {
    /// Nicht in den Katalog: storniert oder abgeschlossen (`done` / `ended`).
    public static func shouldDrop(_ statusRaw: String?) -> Bool {
        if BookingStatus.parse(statusRaw) == .cancelled {
            return true
        }
        switch NonEmpty.string(statusRaw)?.lowercased() {
        case "done", "ended":
            return true
        default:
            return false
        }
    }

    /// Kein Detail-Fetch bei cancelled (Katalog oder GraphQL-Enrich, z. B. Opodo HTML-Walk).
    public static func shouldFetchDetails(_ statusRaw: String?) -> Bool {
        BookingStatus.parse(statusRaw) != .cancelled
    }
}
