import Foundation

/// Normalisierung und Validierung optionaler GitHub-Benutzernamen für Issue-Meldungen.
public enum GitHubUsername {
    public static let maxLength = 39

    public static func normalized(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") {
            value = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    public static func optionalValid(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = normalized(raw)
        guard isValid(normalized) else { return nil }
        return normalized
    }

    /// GitHub-Login: 1–`maxLength` Zeichen, alphanumerisch und Bindestrich, kein führendes/abschließendes `-`.
    public static func isValid(_ normalized: String) -> Bool {
        let range = NSRange(normalized.startIndex..., in: normalized)
        return loginRegex.firstMatch(in: normalized, range: range) != nil
    }

    public static func validationError(for raw: String) -> String? {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return isValid(normalized(raw)) ? nil : "Ungültiger GitHub-Benutzername."
    }

    private static let loginRegex: NSRegularExpression = {
        let pattern = "^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,\(maxLength - 2)}[a-zA-Z0-9])?$"
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("GitHub-Username-Muster ungültig: \(error)")
        }
    }()
}
