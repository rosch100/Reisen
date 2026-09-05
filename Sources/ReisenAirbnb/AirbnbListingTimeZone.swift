import Foundation

enum AirbnbListingTimeZone {
    /// Invalid IANA → nil (kein Geräte-TZ-Fallback); Caller diagnostiziert Skip.
    static func offsetSeconds(listingTimeZone: String, at date: Date) -> Int? {
        guard let timeZone = TimeZone(identifier: listingTimeZone) else { return nil }
        return timeZone.secondsFromGMT(for: date)
    }
}
