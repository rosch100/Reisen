import Foundation

extension BookingComParsing {
    /// ISO-8601 with/without fractional seconds; falls back to `yyyy-MM-dd`.
    static func parseISODateTime(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = isoFractionalSeconds().date(from: raw) { return date }
        if let date = isoBasic().date(from: raw) { return date }
        return dayOnlyUTC().date(from: String(raw.prefix(10)))
    }

    static func isoFractionalSeconds() -> ISO8601DateFormatter {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional
    }

    static func isoBasic() -> ISO8601DateFormatter {
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic
    }
}
