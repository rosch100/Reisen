import Foundation

/// Straße, PLZ+Ort, Land — nur vorhandene Teile (Check24/Opodo-SSOT).
public enum PostalAddress {
    public static func cityLine(city: String?, postalCode: String?) -> String? {
        NonEmpty.combine(postalCode, city) { zip, city in "\(zip) \(city)" }
    }

    public static func lines(
        street: String?,
        postalCode: String?,
        city: String?,
        country: String?
    ) -> String? {
        let parts = [
            NonEmpty.string(stripLeadingSeparators(street)),
            cityLine(city: city, postalCode: postalCode),
            NonEmpty.string(country),
        ].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    /// Leerer Stations-/Ortsname vor dem Komma (FLOYT: `", Flughafen …"`).
    public static func stripLeadingSeparators(_ value: String?) -> String? {
        guard var text = NonEmpty.string(value) else { return nil }
        while let first = text.first, first == "," || first == ";" {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return NonEmpty.string(text)
    }
}
