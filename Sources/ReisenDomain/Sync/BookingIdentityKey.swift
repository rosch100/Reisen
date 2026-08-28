import Foundation

/// In-Memory-Schlüssel für Enrichment-Maps (URL vor Confirmation+Start).
public enum BookingIdentityKey {
    public static func make(externalUrl: String?, confirmationCode: String?, startAt: Date) -> String? {
        if let url = externalUrl, !url.isEmpty {
            return "url:\(url)"
        }
        if let confirmationCode, !confirmationCode.isEmpty {
            return "conf:\(confirmationCode)|start:\(startAt.timeIntervalSince1970)"
        }
        return nil
    }
}
