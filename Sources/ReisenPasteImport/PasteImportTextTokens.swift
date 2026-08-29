import Foundation
import ReisenDomain

/// Normalisierte Wort-Tokens aus Tickettext (DE/EN, ohne Diakritik).
enum PasteImportTextTokens {
    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    static func tokens(in value: String) -> Set<String> {
        Set(
            normalize(value)
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    static func tokens(in value: String?) -> Set<String> {
        guard let value = NonEmpty.string(value) else { return [] }
        return tokens(in: value)
    }

    /// Tokens mit mindestens drei Zeichen — für Grounding gegen Zufallstreffer.
    static func significant(in value: String) -> Set<String> {
        Set(tokens(in: value).filter { $0.count >= 3 })
    }
}
