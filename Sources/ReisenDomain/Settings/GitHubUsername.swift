import Foundation

/// Normalisierung und Validierung optionaler GitHub-Benutzernamen für Issue-Meldungen.
public enum GitHubUsername {
    public static func normalized(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") {
            value = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    /// GitHub-Login: 1–39 Zeichen, alphanumerisch und Bindestrich, kein führendes/abschließendes `-`.
    public static func isValid(_ normalized: String) -> Bool {
        guard !normalized.isEmpty, normalized.count <= 39 else { return false }
        let pattern = #"^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$"#
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }

    public static func validationError(for raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = normalized(trimmed)
        return isValid(normalized) ? nil : "Ungültiger GitHub-Benutzername."
    }
}
