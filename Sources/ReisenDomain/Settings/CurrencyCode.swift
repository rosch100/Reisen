import Foundation

/// ISO-4217-Normalisierung (SSOT für Settings, TripCost, FX).
public enum CurrencyCode {
    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
