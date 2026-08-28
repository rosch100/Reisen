import Foundation
import ReisenDomain

/// Shared HTML heuristics for prep-relevant stay hints (linen, towels, important notices).
/// Used by Check24 / Opodo detail pages. Returns empty when nothing matches — no dummy content.
public enum StayHintHTMLExtractor {
    public static func extract(
        from html: String,
        providerRaw: String
    ) -> [BookingGuestHint] {
        let text = HTMLPlainText.flatten(html)
        guard !text.isEmpty else { return [] }

        var hints: [BookingGuestHint] = []
        hints.append(contentsOf: linenHints(in: text, providerRaw: providerRaw))
        hints.append(contentsOf: importantNoticeHints(in: text, providerRaw: providerRaw))
        return BookingGuestHint.dedupedBySourceKey(hints)
    }

    private static func linenHints(in text: String, providerRaw: String) -> [BookingGuestHint] {
        let patterns: [(needle: String, title: String, detail: String, key: String)] = [
            (
                "bettwäsche wird nicht",
                "Bettwäsche",
                "Bettwäsche wird nicht gestellt — bitte selbst mitbringen oder vor Ort klären.",
                "linen:not_provided"
            ),
            (
                "handtücher selbst",
                "Handtücher",
                "Handtücher selbst mitbringen.",
                "towels:bring_own"
            ),
            (
                "handtücher werden nicht",
                "Handtücher",
                "Handtücher werden nicht gestellt — bitte selbst mitbringen.",
                "towels:not_provided"
            ),
            (
                "towels/sheets (extra fee)",
                "Bettwäsche / Handtücher",
                "Towels/sheets (extra fee) — Bettwäsche und Handtücher ggf. gegen Gebühr.",
                "towels_sheets:extra_fee"
            ),
            (
                "bed linens and towels are not included",
                "Bettwäsche / Handtücher",
                "Bed linens and towels are not included in the room rate.",
                "linen:not_included_en"
            ),
            (
                "hotelchainbedlinen",
                "Bettwäsche / Handtücher",
                "Bettwäsche und Handtücher sind nicht im Zimmerpreis enthalten.",
                "standard_phrase:HotelChainBedLinen"
            ),
        ]

        let lower = text.lowercased()
        var result: [BookingGuestHint] = []
        for pattern in patterns {
            guard lower.contains(pattern.needle) else { continue }
            result.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: pattern.title,
                    detail: pattern.detail,
                    sourceKey: "\(providerRaw):html:\(pattern.key)",
                    providerRaw: providerRaw
                )
            )
        }
        return result
    }

    private static func importantNoticeHints(in text: String, providerRaw: String) -> [BookingGuestHint] {
        let markers = [
            "wichtige hinweise",
            "wichtige informationen",
            "important information",
            "important notice",
        ]
        let lower = text.lowercased()
        for marker in markers {
            guard let range = lower.range(of: marker) else { continue }
            let start = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
            let snippet = String(text[start...]).prefix(400)
            let cleaned = String(snippet)
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count > marker.count + 10 else { continue }
            guard BookingGuestHintPrepKeywords.matches(cleaned) else { continue }
            return [
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Wichtige Hinweise",
                    detail: cleaned,
                    sourceKey: "\(providerRaw):html:important_notice",
                    providerRaw: providerRaw
                ),
            ]
        }
        return []
    }
}
