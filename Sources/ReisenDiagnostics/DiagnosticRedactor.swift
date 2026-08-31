import Foundation

public enum DiagnosticRedactor {
    /// Nur Host (lowercased) — Pfade können Buchungs-/Account-IDs enthalten.
    public static func urlMetadata(for url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else { return nil }
        return host.lowercased()
    }

    public static func urlMetadata(for rawValue: String) -> String? {
        guard let url = URL(string: rawValue) else { return nil }
        if url.host != nil {
            return urlMetadata(for: url)
        }
        guard let urlWithScheme = URL(string: "https://\(rawValue)") else { return nil }
        return urlMetadata(for: urlWithScheme)
    }

    public static func redact(_ text: String) -> String {
        var redacted = SecretRedactor.redact(text)
        for rule in rules {
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = rule.stringByReplacingMatches(
                in: redacted,
                range: range,
                withTemplate: "[redacted]"
            )
        }
        return redacted
    }

    private static let rules: [NSRegularExpression] = [
        compile(#"(?i)\b[\w.%+-]+@[\w.-]+\.[A-Z]{2,}\b"#),
        compile(#"(?i)\b(password|passwort|kennwort|token|secret|cookie|authorization)\s*[:=]\s*\S+"#),
        compile(#"(?i)\b(?:booking(?:number|reference)?|pnr|confirmation(?:\s+code)?)\s*[:=]\s*\S+"#),
    ]

    private static func compile(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Ungültiges Diagnose-Redaction-Muster: \(pattern)")
        }
    }
}
