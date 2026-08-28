import Foundation

extension BookingStatus {
    /// Exakte API-Tokens. Keine Substring-Heuristik außer Cancel-Token-Formen
    /// (`BOOKING_CANCELLED`, `CANCEL_*`) und explizitem `CANCELLABLE`-Ausschluss.
    public static func parseToken(_ raw: String?) -> BookingStatus {
        guard let trimmed = NonEmpty.string(raw) else { return .unknown }

        let upper = trimmed.uppercased()
        if upper.contains("CANCELLABLE") || upper.contains("CANCELABLE") {
            return .unknown
        }
        if Self.confirmedExact.contains(upper) {
            return .confirmed
        }
        if Self.cancelledExact.contains(upper) {
            return .cancelled
        }
        if !trimmed.contains(where: \.isWhitespace),
           upper.contains("CANCELLED") || upper.contains("CANCELED")
        {
            return .cancelled
        }
        if upper == "CANCEL" || upper.hasPrefix("CANCEL_") || upper.hasSuffix("_CANCEL") {
            return .cancelled
        }
        return .unknown
    }

    /// Ein oder mehrere Extract-Strings: Tokens zuerst (Storno vor Confirmed), dann Freitext.
    public static func parse(_ raw: String?) -> BookingStatus {
        guard let raw = NonEmpty.string(raw) else { return .unknown }
        let pieces = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        return parse(parts: pieces.isEmpty ? [raw] : pieces)
    }

    public static func parse(parts: [String?]) -> BookingStatus {
        let pieces = parts.compactMap(NonEmpty.string)
        guard !pieces.isEmpty else { return .unknown }

        var sawConfirmed = false
        for piece in pieces {
            switch parseToken(piece) {
            case .cancelled:
                return .cancelled
            case .confirmed:
                sawConfirmed = true
            case .unknown:
                break
            }
        }
        if sawConfirmed {
            return .confirmed
        }
        return parseFreetext(pieces.joined(separator: " "))
    }

    /// Mehrere Extract-Tokens als `statusRaw` für `parse` (Zeilenumbruch = Whitespace-Splitter).
    public static func joinedRaw(_ parts: [String?]) -> String? {
        let joined = parts.compactMap(NonEmpty.string).joined(separator: "\n")
        return NonEmpty.string(joined)
    }

    public static func joinedRaw(_ parts: String?...) -> String? {
        joinedRaw(Array(parts))
    }

    private static func parseFreetext(_ raw: String) -> BookingStatus {
        let lower = raw.lowercased()
        if lower.contains("refundable") {
            return .unknown
        }
        if lower.contains("non-cancel") || lower.contains("noncancel") {
            return .unknown
        }
        if lower.contains("cancellable") || lower.contains("cancelable") {
            return .unknown
        }
        if lower.contains("cancellation_available") || lower.contains("cancellation available") {
            return .unknown
        }
        if lower.contains("pending_cancellation") {
            return .unknown
        }
        if lower.contains("storniert") {
            return .cancelled
        }
        if lower.contains("cancel") || lower.contains("refunded") {
            return .cancelled
        }
        if lower.contains("voucher issued")
            || lower.contains("e-ticket issued")
            || lower.contains("eticket issued")
        {
            return .confirmed
        }
        return .unknown
    }

    private static let confirmedExact: Set<String> = [
        "CONFIRMED",
        "ACTIVE",
        "ISSUED",
        "ETICKET_PUBLISHED",
        "CONTRACT",
        "UPCOMING",
        "ACCEPT",
        "ACCEPTED",
    ]

    private static let cancelledExact: Set<String> = [
        "CANCELLED",
        "CANCELED",
        "REFUNDED",
        "TERMINATED",
        "RETAINED",
        "FINAL_RET",
        "DIDNOTBUY",
        "DID_NOT_BUY",
        "VOID",
        "CANCELLATION_IN_PROGRESS",
        "CANCELLATION_SUCCESS",
        "CANCELLATION_COMPLETED",
    ]
}
