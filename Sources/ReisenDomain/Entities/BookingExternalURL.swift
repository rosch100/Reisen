import Foundation

/// SSOT für externe Buchungs-URLs (Browser öffnen vs. manuelle Pseudo-URLs).
public enum BookingExternalURL {
    public static let manualPrefix = "reisen://manual/"

    private static let browserSchemes: Set<String> = ["https", "http"]

    public static func makeManual(uuid: UUID = UUID()) -> String {
        "\(manualPrefix)\(uuid.uuidString)"
    }

    /// Öffentliche Browser-URL, oder `nil` bei fehlendem/manuellem/gefährlichem Scheme.
    public static func browserURL(from externalUrl: String?) -> URL? {
        guard let urlString = externalUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty,
              !urlString.hasPrefix(manualPrefix),
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              browserSchemes.contains(scheme) else {
            return nil
        }
        return url
    }

    /// Speichern im Editor: manuelle Pseudo-URLs oder Browser-Schemes.
    public static func isValidStoredURL(_ externalUrl: String) -> Bool {
        let trimmed = externalUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix(manualPrefix) { return true }
        return browserURL(from: trimmed) != nil
    }
}
