import Foundation

enum TravelokaJSON {
    static func object(from text: String) throws -> [String: Any] {
        guard let data = text.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw TravelokaProviderError.invalidResponse
        }
        return root
    }

    static func dataObject(from root: [String: Any]) -> [String: Any]? {
        root["data"] as? [String: Any]
    }

    static func itineraryEntries(from responseText: String) throws -> [[String: Any]] {
        let root = try object(from: responseText)
        guard let data = dataObject(from: root),
              let entries = data["itineraryEntryList"] as? [[String: Any]]
        else {
            throw TravelokaProviderError.invalidResponse
        }
        return entries
    }

    static func firstItineraryEntry(from responseText: String) throws -> [String: Any] {
        let entries = try itineraryEntries(from: responseText)
        guard let entry = entries.first else {
            throw TravelokaProviderError.invalidResponse
        }
        return entry
    }

    static func cardSummary(from entry: [String: Any]) -> [String: Any] {
        (entry["cardSummaryInfo"] as? [String: Any]) ?? [:]
    }

    static func cardDetail(from entry: [String: Any]) -> [String: Any] {
        (entry["cardDetailInfo"] as? [String: Any]) ?? [:]
    }

    static func commonSummary(from entry: [String: Any]) -> [String: Any] {
        let summary = cardSummary(from: entry)
        return (summary["commonSummary"] as? [String: Any]) ?? [:]
    }

    static func string(_ value: Any?) -> String? {
        if let s = value as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let n = value as? NSNumber {
            return n.stringValue
        }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let i = Int(s) { return i }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String, let d = Double(s) { return d }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String {
            switch s.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }

    static func dateFromMillis(_ value: Any?) -> Date? {
        guard let millis = double(value) else { return nil }
        return Date(timeIntervalSince1970: millis / 1000.0)
    }

    static func dayComponents(_ value: Any?) -> (year: Int, month: Int, day: Int)? {
        guard let dict = value as? [String: Any],
              let y = int(dict["year"]),
              let m = int(dict["month"]),
              let d = int(dict["day"])
        else {
            return nil
        }
        return (y, m, d)
    }

    static func minutesFromHHMM(_ value: String?) -> Int? {
        guard let value else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    static func dateFromDay(
        _ day: (year: Int, month: Int, day: Int),
        minutes: Int?,
        timeZone: TimeZone
    ) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = timeZone
        components.year = day.year
        components.month = day.month
        components.day = day.day
        if let minutes {
            components.hour = minutes / 60
            components.minute = minutes % 60
        } else {
            components.hour = 0
            components.minute = 0
        }
        return components.date
    }

    static func timeZone(iana: String?) -> TimeZone? {
        guard let iana, let tz = TimeZone(identifier: iana) else { return nil }
        return tz
    }

    /// Lokale Traveloka-Deadline-/Slot-Strings (`2026-09-06T23:59:00`).
    static func localDateTime(_ value: String, timeZone: TimeZone) -> Date? {
        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm"]
        for format in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = timeZone
            df.dateFormat = format
            if let date = df.date(from: value) {
                return date
            }
        }
        return nil
    }
}
