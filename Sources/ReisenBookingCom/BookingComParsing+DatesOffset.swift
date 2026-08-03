import Foundation

extension BookingComParsing {
    /// Offset from trailing `+HH:MM` / `-HHMM` in an ISO datetime string.
    static func offsetSeconds(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let groups = captures(#"([+-])(\d{2}):?(\d{2})$"#, in: raw)
        guard groups.count >= 3,
              let hours = Int(groups[1]),
              let minutes = Int(groups[2]) else { return nil }
        let sign = groups[0] == "-" ? -1 : 1
        return sign * (hours * 3600 + minutes * 60)
    }

    /// Minutes since midnight from `THH:MM` in an ISO datetime.
    static func clockMinutes(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let groups = captures(#"T(\d{2}):(\d{2})"#, in: raw)
        guard groups.count >= 2,
              let hours = Int(groups[0]),
              let minutes = Int(groups[1]) else { return nil }
        return hours * 60 + minutes
    }
}
