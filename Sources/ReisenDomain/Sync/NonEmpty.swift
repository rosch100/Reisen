import Foundation

/// Trim + Leer → `nil`. SSOT für Extract-/Label-Strings.
public enum NonEmpty {
    public static func string(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Erstes nicht-leeres Token nach Trim.
    public static func first(_ values: String?...) -> String? {
        values.lazy.compactMap(string).first
    }

    /// Beide Teile kombinieren, sonst den vorhandenen.
    public static func combine(
        _ first: String?,
        _ second: String?,
        both: (String, String) -> String
    ) -> String? {
        switch (string(first), string(second)) {
        case let (first?, second?):
            return both(first, second)
        case let (first?, nil):
            return first
        case let (nil, second?):
            return second
        case (nil, nil):
            return nil
        }
    }
}

