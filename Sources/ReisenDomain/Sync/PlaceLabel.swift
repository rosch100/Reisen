import Foundation

/// `"City (IATA)"` bzw. der jeweils vorhandene Teil.
public enum PlaceLabel {
    public static func make(city: String?, iata: String?) -> String? {
        NonEmpty.combine(city, iata) { city, iata in "\(city) (\(iata))" }
    }

    /// `"From → To"` nur wenn beide Teile nicht leer sind.
    public static func route(from: String?, to: String?) -> String? {
        guard let from = NonEmpty.string(from), let to = NonEmpty.string(to) else { return nil }
        return "\(from) → \(to)"
    }
}
