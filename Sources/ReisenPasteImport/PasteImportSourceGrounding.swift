import Foundation
import ReisenDomain

/// Verwirft oder bereinigt Extrakte, die nicht im Quelltext vorkommen (Few-Shot-Leakage).
///
/// Titel- und Ortstokens müssen als eigene Tokens im Quelltext vorkommen — kein Substring in
/// längeren Wörtern (z. B. „main“ in „domain“).
public enum PasteImportSourceGrounding {
    public static func keepingGrounded(
        _ extractions: [PasteImportExtraction],
        in text: String?
    ) -> [PasteImportExtraction] {
        guard let text, !text.isEmpty else { return extractions }
        let hayTokens = tokens(in: text)
        let hayJoined = normalize(text)
        return extractions.compactMap { grounded($0, hayTokens: hayTokens, hayJoined: hayJoined) }
    }

    private static func grounded(
        _ extraction: PasteImportExtraction,
        hayTokens: Set<String>,
        hayJoined: String
    ) -> PasteImportExtraction? {
        if let code = extraction.confirmationCode {
            let codeKey = normalize(code)
            guard hayJoined.contains(codeKey) || hayTokens.contains(codeKey) else {
                return nil
            }
        }
        if let title = extraction.title {
            let titleTokens = significantTokens(title)
            guard titleTokens.isEmpty || titleTokens.isSubset(of: hayTokens) else {
                return nil
            }
        }
        var result = extraction
        if let from = result.locationFrom, !significantTokens(from).isSubset(of: hayTokens) {
            result.locationFrom = nil
        }
        if let to = result.locationTo, !significantTokens(to).isSubset(of: hayTokens) {
            result.locationTo = nil
        }
        return result
    }

    private static func significantTokens(_ value: String) -> Set<String> {
        Set(tokens(in: value).filter { $0.count >= 3 })
    }

    private static func tokens(in value: String) -> Set<String> {
        Set(
            normalize(value)
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
