import Foundation
import ReisenDomain

public struct HotelCheckInOut {
    public let checkInMinutes: Int?
    public let checkOutMinutes: Int?
}

/// Parses hotel check-in/out times from the hotel booking detail HTML.
/// Best-effort: Check24 häufig "Check-in ab 14:00" / "Check-out bis 12:00".
public struct HotelCheckInOutParser {
    public init() {}

    public func parse(from html: String) -> HotelCheckInOut {
        let checkInMinutes = extractTimeMinutes(pattern: #"Check-in\s+ab\s*(\d{1,2}):(\d{2})"#, from: html)
        let checkOutMinutes = extractTimeMinutes(pattern: #"Check-out\s+bis\s*(\d{1,2}):(\d{2})"#, from: html)
        return HotelCheckInOut(checkInMinutes: checkInMinutes, checkOutMinutes: checkOutMinutes)
    }

    private func extractTimeMinutes(pattern: String, from html: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges >= 3 else { return nil }

        let hoursStr = ns.substring(with: match.range(at: 1))
        let minsStr = ns.substring(with: match.range(at: 2))
        guard let hours = Int(hoursStr), let mins = Int(minsStr) else { return nil }
        guard (0...23).contains(hours), (0...59).contains(mins) else { return nil }
        return hours * 60 + mins
    }
}

