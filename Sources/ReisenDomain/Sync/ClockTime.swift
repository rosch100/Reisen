import Foundation

/// Uhrzeit → Minuten seit Mitternacht. SSOT für `hotelCheckInMinutes` / `hotelCheckOutMinutes`.
public enum ClockTime {
    public static func minutes(hours: Int, minute: Int) -> Int? {
        guard (0...23).contains(hours), (0...59).contains(minute) else { return nil }
        return hours * 60 + minute
    }

    /// `"14:00"` / `"9:00"`. Kein Range-String (`14:00-23:59`).
    public static func minutes(fromHHMM raw: String?) -> Int? {
        guard let trimmed = NonEmpty.string(raw) else { return nil }
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return Self.minutes(hours: hours, minute: minute)
    }
}
