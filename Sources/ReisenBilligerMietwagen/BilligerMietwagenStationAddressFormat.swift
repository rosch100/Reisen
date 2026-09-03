import Foundation
import ReisenDomain

/// FLOYT-`street`-Blobs: Leading-Comma, Dedup, zwei Zeilen.
enum BilligerMietwagenStationAddressFormat {
    static func lines(
        street: String?,
        postalCode: String?,
        city: String?,
        country: String?
    ) -> String? {
        let cleanedStreet = PostalAddress.stripLeadingSeparators(street)
        // Nur FLOYT-Leading-Separator-Blobs (`, Flughafen …`); reine Mehr-Komma-Straßen
        // bleiben bei PostalAddress.lines inkl. PLZ/Ort/Land.
        if let cleanedStreet, isFloytDisplayBlob(rawStreet: street) {
            return multiline(
                street: stripTrailingDuplicateCity(cleanedStreet, city: city)
            )
        }
        return PostalAddress.lines(
            street: cleanedStreet,
            postalCode: postalCode,
            city: city,
            country: country
        )
    }

    /// Live-FLOYT: leerer Stationsname vor dem Komma (`", …"` / `"; …"`).
    private static func isFloytDisplayBlob(rawStreet: String?) -> Bool {
        guard let raw = NonEmpty.string(rawStreet), let first = raw.first else { return false }
        return first == "," || first == ";"
    }

    private static func stripTrailingDuplicateCity(_ street: String, city: String?) -> String {
        guard let city = NonEmpty.string(city) else { return street }
        let suffix = ", \(city)"
        guard street.count > suffix.count,
              street.suffix(suffix.count).caseInsensitiveCompare(suffix) == .orderedSame
        else { return street }
        let withoutTrailing = String(street.dropLast(suffix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard withoutTrailing.range(of: city, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        else { return street }
        return withoutTrailing
    }

    /// Stationsname/Straße in Zeile 1, Rest kompakt in Zeile 2.
    private static func multiline(street: String) -> String {
        let parts = street
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return street }
        let head = parts[0]
        let tail = parts.dropFirst().joined(separator: ", ")
        return "\(head)\n\(tail)"
    }
}
