import Foundation

extension BookingComParsing {
    /// Check24-kompatibel: Wanduhrzeit als UTC-Instant + Offset (Normalizer zieht Offset ab).
    struct WallClockStorage: Equatable, Sendable {
        var wallClockAsUTC: Date
        var offsetSeconds: Int
    }

    static func wallClockStorage(fromISO raw: String?) -> WallClockStorage? {
        guard let absolute = parseISODateTime(raw) else { return nil }
        let offset = offsetSeconds(from: raw) ?? 0
        return WallClockStorage(
            wallClockAsUTC: absolute.addingTimeInterval(TimeInterval(offset)),
            offsetSeconds: offset
        )
    }
}
