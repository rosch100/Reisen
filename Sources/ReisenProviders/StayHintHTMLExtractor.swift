import Foundation
import ReisenDomain

/// Shared HTML heuristics for prep-relevant stay hints (linen, important notices).
/// Booking.com house rules pass extra `HintPattern`s; Check24/Opodo use `extract(from:providerRaw:)`.
/// Returns empty when nothing matches — no dummy content.
public enum StayHintHTMLExtractor {
    package struct HintPattern: Sendable {
        let needles: [String]
        let title: String
        let detail: String
        let key: String

        package init(_ needles: String..., title: String, detail: String, key: String) {
            self.needles = needles
            self.title = title
            self.detail = detail
            self.key = key
        }
    }

    public static func extract(from html: String, providerRaw: String) -> [BookingGuestHint] {
        extract(from: html, providerRaw: providerRaw, matching: [], firstMatching: [])
    }

    package static func extract(
        from html: String,
        providerRaw: String,
        matching additional: [HintPattern],
        firstMatching exclusive: [HintPattern]
    ) -> [BookingGuestHint] {
        let original = HTMLPlainText.flatten(html)
        guard !original.isEmpty else { return [] }
        let text = VisibleText(original: original, lowercased: original.lowercased())
        return BookingGuestHint.dedupedBySourceKey(
            stayHints(in: text, providerRaw: providerRaw)
                + allMatches(additional, in: text.lowercased, providerRaw: providerRaw)
                + firstMatch(exclusive, in: text.lowercased, providerRaw: providerRaw)
        )
    }

    private struct VisibleText {
        let original: String
        let lowercased: String
    }

    private static func stayHints(in text: VisibleText, providerRaw: String) -> [BookingGuestHint] {
        allMatches(linenPatterns, in: text.lowercased, providerRaw: providerRaw)
            + importantNoticeHints(in: text, providerRaw: providerRaw)
    }

    private static let linenPatterns: [HintPattern] = [
        HintPattern(
            "bettwäsche wird nicht",
            title: "Bettwäsche",
            detail: "Bettwäsche wird nicht gestellt — bitte selbst mitbringen oder vor Ort klären.",
            key: "linen:not_provided"
        ),
        HintPattern(
            "handtücher selbst",
            title: "Handtücher",
            detail: "Handtücher selbst mitbringen.",
            key: "towels:bring_own"
        ),
        HintPattern(
            "handtücher werden nicht",
            title: "Handtücher",
            detail: "Handtücher werden nicht gestellt — bitte selbst mitbringen.",
            key: "towels:not_provided"
        ),
        HintPattern(
            "towels/sheets (extra fee)",
            title: "Bettwäsche / Handtücher",
            detail: "Towels/sheets (extra fee) — Bettwäsche und Handtücher ggf. gegen Gebühr.",
            key: "towels_sheets:extra_fee"
        ),
        HintPattern(
            "bed linens and towels are not included",
            title: "Bettwäsche / Handtücher",
            detail: "Bed linens and towels are not included in the room rate.",
            key: "linen:not_included_en"
        ),
        HintPattern(
            "hotelchainbedlinen",
            title: "Bettwäsche / Handtücher",
            detail: "Bettwäsche und Handtücher sind nicht im Zimmerpreis enthalten.",
            key: "standard_phrase:HotelChainBedLinen"
        ),
    ]

    private static let importantNoticeMarkers = [
        "wichtige hinweise",
        "wichtige informationen",
        "wichtige information",
        "important information",
        "important notice",
    ]

    private static func importantNoticeHints(
        in text: VisibleText,
        providerRaw: String
    ) -> [BookingGuestHint] {
        for marker in importantNoticeMarkers {
            guard let cleaned = noticeSlice(text.original, marker: marker) else { continue }
            guard cleaned.count > marker.count + 10 else { continue }
            guard BookingGuestHintPrepKeywords.matches(cleaned) else { continue }
            return [
                hint(
                    title: "Wichtige Hinweise",
                    detail: cleaned,
                    key: "important_notice",
                    providerRaw: providerRaw
                ),
            ]
        }
        return []
    }

    private static func noticeSlice(_ original: String, marker: String) -> String? {
        guard let range = original.range(of: marker, options: .caseInsensitive) else { return nil }
        return String(original[range.lowerBound...].prefix(400))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func allMatches(
        _ patterns: [HintPattern],
        in lowercased: String,
        providerRaw: String
    ) -> [BookingGuestHint] {
        patterns.compactMap { pattern in
            guard matches(pattern, in: lowercased) else { return nil }
            return hint(from: pattern, providerRaw: providerRaw)
        }
    }

    private static func firstMatch(
        _ patterns: [HintPattern],
        in lowercased: String,
        providerRaw: String
    ) -> [BookingGuestHint] {
        Array(allMatches(patterns, in: lowercased, providerRaw: providerRaw).prefix(1))
    }

    private static func matches(_ pattern: HintPattern, in lowercased: String) -> Bool {
        pattern.needles.contains { lowercased.contains($0) }
    }

    private static func hint(from pattern: HintPattern, providerRaw: String) -> BookingGuestHint {
        hint(title: pattern.title, detail: pattern.detail, key: pattern.key, providerRaw: providerRaw)
    }

    private static func hint(
        title: String,
        detail: String,
        key: String,
        providerRaw: String
    ) -> BookingGuestHint {
        BookingGuestHint(
            category: .preTravelImportant,
            title: title,
            detail: detail,
            sourceKey: "\(providerRaw):html:\(key)",
            providerRaw: providerRaw
        )
    }
}
