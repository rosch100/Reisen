import Foundation
import ReisenDomain

/// Verwirft oder bereinigt Extrakte, die nicht im Quelltext vorkommen (Few-Shot-Leakage).
///
/// Titel-, Orts- und Code-Tokens müssen als eigene Tokens im Quelltext vorkommen — kein Substring
/// in längeren Wörtern (z. B. „main“ in „domain“).
///
/// **Bild-only:** Ohne eingebetteten Quelltext (`text == nil`) greift Grounding nicht — Tokens lassen
/// sich aus dem Bild nicht ohne OCR ableiten. Leakage-Schutz liegt dann nur bei Instructions/Few-Shots.
public enum PasteImportSourceGrounding {
    public static func keepingGrounded(
        _ extractions: [PasteImportExtraction],
        in text: String?
    ) -> [PasteImportExtraction] {
        guard let text, !text.isEmpty else { return extractions }
        let hayTokens = PasteImportTextTokens.tokens(in: text)
        return extractions.compactMap { grounded($0, hayTokens: hayTokens) }
    }

    private static func grounded(
        _ extraction: PasteImportExtraction,
        hayTokens: Set<String>
    ) -> PasteImportExtraction? {
        if let code = extraction.confirmationCode, !codeGrounded(code, hayTokens: hayTokens) {
            return nil
        }
        if let title = extraction.title, !significantTokensGrounded(title, hayTokens: hayTokens) {
            return nil
        }
        var result = extraction
        result.locationFrom = groundedLocation(result.locationFrom, hayTokens: hayTokens)
        result.locationTo = groundedLocation(result.locationTo, hayTokens: hayTokens)
        return result
    }

    /// Code als ganzes Token oder alle Segmente (z. B. `EXAM-UA-88` → exam, ua, 88) im Quelltext.
    private static func codeGrounded(_ code: String, hayTokens: Set<String>) -> Bool {
        let segments = PasteImportTextTokens.tokens(in: code)
        return !segments.isEmpty && segments.isSubset(of: hayTokens)
    }

    private static func significantTokensGrounded(_ value: String, hayTokens: Set<String>) -> Bool {
        let tokens = PasteImportTextTokens.significant(in: value)
        return tokens.isEmpty || tokens.isSubset(of: hayTokens)
    }

    private static func groundedLocation(_ value: String?, hayTokens: Set<String>) -> String? {
        guard let value else { return nil }
        return significantTokensGrounded(value, hayTokens: hayTokens) ? value : nil
    }
}
