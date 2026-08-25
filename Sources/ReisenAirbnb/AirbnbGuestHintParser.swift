import Foundation
import ReisenDomain

/// Extracts prep-relevant hints from Airbnb stay reservation payloads (JSON text).
public struct AirbnbGuestHintParser: Sendable {
    public init() {}

    public func parse(from responseText: String) -> [BookingGuestHint] {
        let provider = ProviderID.airbnb.rawValue
        let lower = responseText.lowercased()
        var hints: [BookingGuestHint] = []

        if looksLikeMissingEssentials(responseText) {
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Essentials",
                    detail: "Essentials (Bettwäsche, Handtücher, Seife, Toilettenpapier) sind laut Listing nicht (vollständig) vorhanden — vor Reiseantritt prüfen.",
                    sourceKey: "airbnb:amenity:essentials:absent",
                    providerRaw: provider
                )
            )
        }

        if lower.contains("bring your own towels")
            || lower.contains("handtücher selbst")
            || lower.contains("towels not provided")
        {
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Handtücher",
                    detail: "Handtücher selbst mitbringen.",
                    sourceKey: "airbnb:towels:bring_own",
                    providerRaw: provider
                )
            )
        }

        if lower.contains("bring your own linens")
            || lower.contains("bettwäsche selbst")
            || lower.contains("linens not provided")
            || lower.contains("bed linens not provided")
        {
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Bettwäsche",
                    detail: "Bettwäsche selbst mitbringen.",
                    sourceKey: "airbnb:linens:bring_own",
                    providerRaw: provider
                )
            )
        }

        if let houseRulesSnippet = extractHouseRulesSnippet(from: responseText),
           BookingGuestHintPrepKeywords.matches(houseRulesSnippet) {
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Hausregeln",
                    detail: houseRulesSnippet,
                    sourceKey: "airbnb:house_rules:prep",
                    providerRaw: provider
                )
            )
        }

        return BookingGuestHint.dedupedBySourceKey(hints)
    }

    private func looksLikeMissingEssentials(_ text: String) -> Bool {
        let patterns = [
            #""title"\s*:\s*"Essentials"[\s\S]{0,120}?"available"\s*:\s*false"#,
            #""available"\s*:\s*false[\s\S]{0,120}?"title"\s*:\s*"Essentials""#,
            #""id"\s*:\s*"essentials"[\s\S]{0,120}?"available"\s*:\s*false"#,
            #""available"\s*:\s*false[\s\S]{0,120}?"id"\s*:\s*"essentials""#,
        ]
        for pattern in patterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    private func extractHouseRulesSnippet(from text: String) -> String? {
        let markers = ["house_rules", "houseRules", "Hausregeln"]
        for marker in markers {
            guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }
            let start = range.lowerBound
            let end = text.index(start, offsetBy: min(300, text.distance(from: start, to: text.endIndex)))
            let snippet = String(text[start..<end])
                .replacingOccurrences(of: "\\n", with: " ")
                .replacingOccurrences(of: "\"", with: " ")
            let cleaned = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count > 20 { return String(cleaned.prefix(280)) }
        }
        return nil
    }
}
