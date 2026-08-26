import Foundation
import ReisenDomain

extension ActivityListParser {
    /// Hotels: nur Kalenderdatum — Uhrzeit/TZ verwerfen.
    func parseHotelDay(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return HotelStayDate.parse(raw)
    }

    func parseFlexibleDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }

        // ISO-ähnlich: 2026-08-11T23:59:00
        let candidates = [raw, raw.replacingOccurrences(of: "T", with: " ")]
        let isoFormats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        // Activities-API liefert viele ISO-Zeitstempel ohne expliziten Offset.
        // Für die korrekte Ortszeit-Ausgabe formatieren wir später (UI) anhand der Hotel-Ortszeit.
        // Daher: zunächst als UTC interpretieren.
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        for format in isoFormats {
            iso.dateFormat = format
            for candidate in candidates {
                if let date = iso.date(from: candidate) { return date }
            }
        }

        // HAR GMT: Tue Aug 11 2026 23:59:00 GMT+0200
        return parseHarGmtDate(raw)
    }

    private func parseHarGmtDate(_ s: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z"
        return df.date(from: s)
    }
}
