import Foundation

/// SSOT für externe Buchungs-URLs (Browser öffnen vs. manuelle Pseudo-URLs).
public enum BookingExternalURL {
    public static let manualPrefix = "reisen://manual/"

    public static func makeManual(uuid: UUID = UUID()) -> String {
        "\(manualPrefix)\(uuid.uuidString)"
    }

    /// Öffentliche Browser-URL, oder `nil` bei fehlendem/manuellem Wert.
    public static func browserURL(from externalUrl: String?) -> URL? {
        guard let urlString = externalUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty,
              !urlString.hasPrefix(manualPrefix),
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }
}
