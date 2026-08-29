import Foundation
import ReisenDomain

/// Verwirft oder bereinigt Extrakte, die nicht im Quelltext vorkommen (Few-Shot-Leakage).
///
/// Titel-, Orts- und Code-Tokens müssen als eigene Tokens im Quelltext vorkommen — kein Substring
/// in längeren Wörtern (z. B. „main“ in „domain“).
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
        if let code = extraction.confirmationCode {
            guard codeGrounded(code, hayTokens: hayTokens) else { return nil }
        }
        if let title = extraction.title {
            let titleTokens = PasteImportTextTokens.significant(in: title)
            guard titleTokens.isEmpty || titleTokens.isSubset(of: hayTokens) else {
                return nil
            }
        }
        var result = extraction
        if let from = result.locationFrom,
           !PasteImportTextTokens.significant(in: from).isSubset(of: hayTokens)
        {
            result.locationFrom = nil
        }
        if let to = result.locationTo,
           !PasteImportTextTokens.significant(in: to).isSubset(of: hayTokens)
        {
            result.locationTo = nil
        }
        return result
    }

    /// Code als ganzes Token oder alle Segmente (z. B. `EXAM-UA-88` → exam, ua, 88) im Quelltext.
    private static func codeGrounded(_ code: String, hayTokens: Set<String>) -> Bool {
        let codeKey = PasteImportTextTokens.normalize(code)
        if hayTokens.contains(codeKey) { return true }
        let segments = PasteImportTextTokens.tokens(in: code)
        return !segments.isEmpty && segments.isSubset(of: hayTokens)
    }
}
