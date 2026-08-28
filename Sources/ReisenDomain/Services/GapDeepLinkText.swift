import Foundation

/// Gemeinsame Format-/Token-Hilfen für Gap-Such-URLs (SSOT).
public enum GapDeepLinkText {
    public static let isoDayFormat = "yyyy-MM-dd"
    public static let travelokaDayFormat = "dd-MM-yyyy"

    /// Default Erwachsene für Hotel-/Homes-Gap-Suche (kein Trip-Guest-Count).
    public static let defaultLodgingAdults = "2"
    /// Default Erwachsene für One-Way-Flugsuche.
    public static let defaultFlightAdults = "1"

    public static func posixDay(_ date: Date, format: String = isoDayFormat) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = format
        return df.string(from: date)
    }

    /// Erster dreistelliger IATA-Code in einem Hinweistext (z. B. „Frankfurt (FRA)“ → FRA).
    public static func firstIATA(in hint: String?) -> String? {
        guard let hint else { return nil }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let regex = try? NSRegularExpression(
            pattern: #"\b[A-Z]{3}\b"#,
            options: .caseInsensitive
        ) else { return nil }
        let ns = trimmed as NSString
        let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
        guard let match = matches.first else { return nil }
        return ns.substring(with: match.range).uppercased(with: Locale(identifier: "en_US_POSIX"))
    }
}
