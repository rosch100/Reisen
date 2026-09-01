import Foundation

/// Double→Decimal an JSON/SD-Grenzen ohne Binärrauschen (`Decimal(Double)` vermeiden).
public enum DecimalJSON {
    public static func parse(_ value: Double) -> Decimal? {
        Decimal(string: String(format: "%.8f", value))
    }
}
