import Foundation
import ReisenDomain

/// Verwirft oder bereinigt Extrakte, die nicht im Quelltext vorkommen (Few-Shot-Leakage).
public enum PasteImportSourceGrounding {
    public static func keepingGrounded(
        _ extractions: [PasteImportExtraction],
        in text: String?
    ) -> [PasteImportExtraction] {
        guard let text, !text.isEmpty else { return extractions }
        let hay = normalize(text)
        return extractions.compactMap { grounded($0, hay: hay) }
    }

    private static func grounded(
        _ extraction: PasteImportExtraction,
        hay: String
    ) -> PasteImportExtraction? {
        if let code = extraction.confirmationCode, !hay.contains(normalize(code)) {
            return nil
        }
        if let title = extraction.title, !titleAppears(title, in: hay) {
            return nil
        }
        var result = extraction
        if let from = result.locationFrom, !tokenAppears(from, in: hay) {
            result.locationFrom = nil
        }
        if let to = result.locationTo, !tokenAppears(to, in: hay) {
            result.locationTo = nil
        }
        return result
    }

    private static func titleAppears(_ title: String, in hay: String) -> Bool {
        let tokens = significantTokens(title)
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { hay.contains($0) }
    }

    private static func tokenAppears(_ value: String, in hay: String) -> Bool {
        let tokens = significantTokens(value)
        guard !tokens.isEmpty else { return true }
        return tokens.contains { hay.contains($0) }
    }

    private static func significantTokens(_ value: String) -> [String] {
        normalize(value)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
