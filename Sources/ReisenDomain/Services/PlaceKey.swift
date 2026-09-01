import Foundation

/// Deterministische Ortsschlüssel für räumliche Lücken (kein Geocoding).
public enum PlaceKey {
    public static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let iata = parentheticalIata(in: trimmed) {
            return iata
        }
        if trimmed.count == 3, trimmed.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
            return trimmed.uppercased()
        }
        return trimmed.lowercased()
    }

    private static func parentheticalIata(in text: String) -> String? {
        guard let open = text.firstIndex(of: "("),
              let close = text.firstIndex(of: ")"),
              open < close
        else { return nil }
        let inner = text[text.index(after: open)..<close]
        let token = String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.count == 3, token.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) else {
            return nil
        }
        return token.uppercased()
    }
}
