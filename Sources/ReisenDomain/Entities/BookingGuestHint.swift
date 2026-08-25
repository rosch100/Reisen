import Foundation

public enum GuestHintCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case preTravelImportant

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .preTravelImportant:
            return "Wichtige Hinweise vor Reiseantritt"
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

public enum BookingGuestHintSummary {
    /// Compact body for notifications (max 3 lines).
    public static func notificationBody(bookingTitle: String, hints: [BookingGuestHint]) -> String {
        let lines = hints.prefix(3).map { hint in
            let detail = hint.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty { return "• \(hint.title)" }
            let clipped = detail.count > 80 ? String(detail.prefix(77)) + "…" : detail
            return "• \(hint.title): \(clipped)"
        }
        let joined = lines.joined(separator: "\n")
        if hints.count > 3 {
            return "\(bookingTitle)\n\(joined)\n… +\(hints.count - 3) weitere"
        }
        return "\(bookingTitle)\n\(joined)"
    }
}
