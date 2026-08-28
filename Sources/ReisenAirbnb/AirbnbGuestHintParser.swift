import Foundation
import ReisenDomain

/// Extracts prep-relevant hints from Airbnb stay reservation-overview JSON.
/// Only `house_rules` and `house_manual` rows (Stay-Detail, visible phrases) — no dummy content.
public struct AirbnbGuestHintParser: Sendable {
    public init() {}

    public func parse(from responseText: String) -> [BookingGuestHint] {
        guard let envelope = decode(responseText) else { return [] }
        let provider = ProviderID.airbnb.rawValue
        let hints = envelope.scheduledEvent.rows.flatMap { hints(from: $0, providerRaw: provider) }
        return BookingGuestHint.dedupedBySourceKey(hints)
    }

    private func hints(from row: AirbnbStayHintRow, providerRaw: String) -> [BookingGuestHint] {
        switch StayHintKind(rawValue: row.id) {
        case .houseRules:
            return houseRuleHints(from: row, providerRaw: providerRaw)
        case .houseManual:
            return asHints(fragmentHint(from: row, kind: .houseManual, providerRaw: providerRaw))
        case nil:
            return []
        }
    }

    /// One hint per matching house-rule item so each shows in the booking UI.
    private func houseRuleHints(
        from row: AirbnbStayHintRow,
        providerRaw: String
    ) -> [BookingGuestHint] {
        let itemHints = row.houseRuleItems.compactMap {
            houseRuleHint(from: $0, row: row, providerRaw: providerRaw)
        }
        if !itemHints.isEmpty { return itemHints }
        return asHints(fragmentHint(from: row, kind: .houseRules, providerRaw: providerRaw))
    }

    private func houseRuleHint(
        from item: AirbnbStayHintRuleItem,
        row: AirbnbStayHintRow,
        providerRaw: String
    ) -> BookingGuestHint? {
        let combined = item.displayText
        guard BookingGuestHintPrepKeywords.matches(combined) else { return nil }
        let title = NonEmpty.string(item.title)
            ?? NonEmpty.string(row.title)
            ?? StayHintKind.houseRules.fallbackTitle
        let rawDetail = NonEmpty.string(item.subtitle) ?? combined
        return makeHint(
            title: title,
            rawDetail: rawDetail,
            sourceKey: Self.houseRuleSourceKey(title: title, detail: rawDetail),
            providerRaw: providerRaw
        )
    }

    private func fragmentHint(
        from row: AirbnbStayHintRow,
        kind: StayHintKind,
        providerRaw: String
    ) -> BookingGuestHint? {
        let fragments = row.visibleFragments
        let joined = fragments.joined(separator: " ")
        guard BookingGuestHintPrepKeywords.matches(joined) else { return nil }
        let matching = fragments.filter { BookingGuestHintPrepKeywords.matches($0) }
        return makeHint(
            title: NonEmpty.string(row.title) ?? kind.fallbackTitle,
            rawDetail: matching.last ?? joined,
            sourceKey: kind.sourceKey,
            providerRaw: providerRaw
        )
    }

    private func makeHint(
        title: String,
        rawDetail: String,
        sourceKey: String,
        providerRaw: String
    ) -> BookingGuestHint? {
        let detail = Self.prepDetail(from: rawDetail)
        guard !detail.isEmpty else { return nil }
        return BookingGuestHint(
            category: .preTravelImportant,
            title: title,
            detail: detail,
            sourceKey: sourceKey,
            providerRaw: providerRaw
        )
    }

    private func asHints(_ hint: BookingGuestHint?) -> [BookingGuestHint] {
        hint.map { [$0] } ?? []
    }

    private func decode(_ responseText: String) -> AirbnbStayHintEnvelope? {
        try? AirbnbJSONDecoder.shared.decode(
            AirbnbStayHintEnvelope.self,
            from: Data(responseText.utf8)
        )
    }
}

private enum StayHintKind: String {
    case houseRules = "house_rules"
    case houseManual = "house_manual"

    var sourceKey: String {
        switch self {
        case .houseRules: "airbnb:house_rules:prep"
        case .houseManual: "airbnb:house_manual:prep"
        }
    }

    var fallbackTitle: String {
        switch self {
        case .houseRules: "Hausregeln"
        case .houseManual: "Gäste-Handbuch"
        }
    }
}

private enum FNV1a64 {
    static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    static let prime: UInt64 = 1_099_511_628_211
}

private extension AirbnbGuestHintParser {
    static let detailMaxLength = 280

    static func houseRuleSourceKey(title: String, detail: String) -> String {
        "\(StayHintKind.houseRules.sourceKey):\(fnv1aHex("\(title)\u{1e}\(detail)"))"
    }

    static func fnv1aHex(_ text: String) -> String {
        var hash = FNV1a64.offsetBasis
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* FNV1a64.prime
        }
        return String(hash, radix: 16)
    }

    static func prepDetail(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > detailMaxLength else { return trimmed }
        let prefix = String(trimmed.prefix(detailMaxLength))
        if BookingGuestHintPrepKeywords.matches(prefix) {
            return prefix
        }
        return excerptAroundFirstPrepMatch(trimmed)
    }

    static func excerptAroundFirstPrepMatch(_ text: String) -> String {
        guard let match = BookingGuestHintPrepKeywords.firstRange(in: text) else {
            return String(text.prefix(detailMaxLength))
        }
        let matchLength = text.distance(from: match.lowerBound, to: match.upperBound)
        if matchLength >= detailMaxLength {
            return window(text, from: match.lowerBound, length: detailMaxLength)
        }
        let leadingPad = (detailMaxLength - matchLength) / 2
        let start = text.index(match.lowerBound, offsetBy: -leadingPad, limitedBy: text.startIndex)
            ?? text.startIndex
        return window(text, from: start, length: detailMaxLength)
    }

    static func window(_ text: String, from start: String.Index, length: Int) -> String {
        let end = text.index(start, offsetBy: length, limitedBy: text.endIndex) ?? text.endIndex
        guard text.distance(from: start, to: end) < length else {
            return String(text[start..<end])
        }
        let backfilledStart = text.index(end, offsetBy: -length, limitedBy: text.startIndex)
            ?? text.startIndex
        return String(text[backfilledStart..<end])
    }
}
