import Foundation

/// ISO-4217-Normalisierung (SSOT für Settings, TripCost, FX).
public enum CurrencyCode {
    /// Ultima-Fallback wenn weder Setting noch Locale eine Währung liefern.
    public static let fallback = "EUR"

    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
