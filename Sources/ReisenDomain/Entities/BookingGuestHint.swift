import Foundation

public enum GuestHintCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case preTravelImportant

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .preTravelImportant:
            return L10n.string(.guestHintPreTravelImportant)
        }
    }
}

/// Provider-agnostic guest-facing hint (linen, meeting point, restrictions, …).
public struct BookingGuestHint: Identifiable, Equatable, Sendable, Codable {
    public var id: UUID
    public var bookingID: UUID?
    public var category: GuestHintCategory
    public var title: String
    public var detail: String
    /// Stable dedup key, e.g. `gyg:restriction:Alkohol und Drogen`.
    public var sourceKey: String
    public var providerRaw: String?

    public init(
        id: UUID = UUID(),
        bookingID: UUID? = nil,
        category: GuestHintCategory = .preTravelImportant,
        title: String,
        detail: String,
        sourceKey: String,
        providerRaw: String? = nil
    ) {
        self.id = id
        self.bookingID = bookingID
        self.category = category
        self.title = title
        self.detail = detail
        self.sourceKey = sourceKey
        self.providerRaw = providerRaw
    }
}

extension BookingGuestHint {
    public static func dedupedBySourceKey(_ hints: [BookingGuestHint]) -> [BookingGuestHint] {
        var seen = Set<String>()
        return hints.filter { seen.insert($0.sourceKey).inserted }
    }

    public static func merged(existing: [BookingGuestHint], with new: [BookingGuestHint]) -> [BookingGuestHint] {
        var seen = Set(existing.map(\.sourceKey))
        var merged = existing
        for hint in new where seen.insert(hint.sourceKey).inserted {
            merged.append(hint)
        }
        return merged
    }

    public static func manualPersistable(from draft: BookingGuestHint, bookingID: UUID) -> BookingGuestHint? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !detail.isEmpty else { return nil }
        return BookingGuestHint(
            id: draft.id,
            bookingID: bookingID,
            category: draft.category,
            title: title,
            detail: detail,
            sourceKey: draft.sourceKey.isEmpty ? "manual:\(draft.id.uuidString)" : draft.sourceKey,
            providerRaw: draft.providerRaw ?? ProviderID.manual.rawValue
        )
    }
}

public enum BookingGuestHintSummary {
    public static func notificationBody(bookingTitle: String, hints: [BookingGuestHint]) -> String {
        let lines = hints.prefix(3).map { hint in
            let detail = hint.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty { return "• \(hint.title)" }
            let clipped = detail.count > 80 ? String(detail.prefix(77)) + "…" : detail
            return "• \(hint.title): \(clipped)"
        }
        let joined = lines.joined(separator: "\n")
        if hints.count > 3 {
            return "\(bookingTitle)\n\(joined)\n\(L10n.format(.guestHintMoreCount, hints.count - 3))"
        }
        return "\(bookingTitle)\n\(joined)"
    }

    /// Stable fingerprint for scheduler/EventKit dedup when hint text changes.
    public static func contentFingerprint(hints: [BookingGuestHint]) -> String {
        hints
            .sorted { $0.sourceKey < $1.sourceKey }
            .map { "\($0.sourceKey)|\($0.title)|\($0.detail)" }
            .joined(separator: ";")
    }

    public static func eventTitle(bookingTitle: String) -> String {
        "\(GuestHintCategory.preTravelImportant.displayTitle): \(bookingTitle)"
    }

    public static func eventNotes(leadDays: Int, summary: String) -> String {
        """
        \(L10n.format(.guestHintEventNotesHeader, GuestHintCategory.preTravelImportant.displayTitle))
        \(L10n.format(.guestHintLeadDays, leadDays))
        \(summary)
        """
    }

    public static func reminderNotes(summary: String) -> String {
        "\(L10n.format(.guestHintReminderNotesHeader, GuestHintCategory.preTravelImportant.displayTitle))\n\(summary)"
    }
}

public enum BookingGuestHintPrepKeywords {
    public static let all: [String] = [
        "linen", "linens", "towel", "towels", "bettwäsche", "handtuch", "handtücher",
        "mitbringen", "nicht enthalten", "not included", "not provided", "extra fee",
        "bring your own", "selbst mitbringen", "wird nicht gestellt",
        "eigene bettwäsche", "keine wäsche",
    ]

    public static func matches(_ text: String) -> Bool {
        firstRange(in: text) != nil
    }

    public static func firstRange(in text: String) -> Range<String.Index>? {
        all.compactMap { text.range(of: $0, options: .caseInsensitive) }
            .min { $0.lowerBound < $1.lowerBound }
    }
}

extension Booking {
    public var preTravelImportantHints: [BookingGuestHint] {
        guestHints.filter { $0.category == .preTravelImportant }
    }

    public var hasPreTravelImportantHints: Bool {
        !preTravelImportantHints.isEmpty
    }
}

extension Array where Element == Booking {
    public func withPreTravelImportantHints() -> [Booking] {
        filter(\.hasPreTravelImportantHints)
    }
}
