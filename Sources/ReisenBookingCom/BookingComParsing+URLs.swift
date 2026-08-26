import Foundation
import ReisenProviders

extension BookingComParsing {
    static let secureBookingOrigin = "https://secure.booking.com"

    static func absoluteBookingURL(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return raw }
        if raw.hasPrefix("/") { return secureBookingOrigin + raw }
        return secureBookingOrigin + "/" + raw
    }

    /// GraphQL liefert z. B. `confirmation.en-us.html` / `confirmation.de.html`.
    /// Fee-Schedule-SSOT: locale-neutrale `confirmation.html` mit kanonischer EN-Sprache.
    static func normalizedHotelConfirmationURL(_ raw: String?) -> String? {
        guard var url = absoluteBookingURL(raw) else { return nil }
        if let regex = try? NSRegularExpression(
            pattern: #"confirmation(?:\.[A-Za-z]{2}(?:-[A-Za-z]{2})?)?\.html"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(url.startIndex..<url.endIndex, in: url)
            url = regex.stringByReplacingMatches(
                in: url,
                options: [],
                range: range,
                withTemplate: "confirmation.html"
            )
        }
        guard url.range(of: "confirmation.html", options: .caseInsensitive) != nil else {
            return url
        }
        if let langRegex = try? NSRegularExpression(pattern: #"lang=[^;&]+"#, options: [.caseInsensitive]) {
            let range = NSRange(url.startIndex..<url.endIndex, in: url)
            if langRegex.firstMatch(in: url, options: [], range: range) != nil {
                url = langRegex.stringByReplacingMatches(
                    in: url,
                    options: [],
                    range: range,
                    withTemplate: "lang=\(ProviderSyncLocale.language)"
                )
            } else {
                url += url.contains("?") ? ";lang=\(ProviderSyncLocale.language)" : "?lang=\(ProviderSyncLocale.language)"
            }
        }
        return url
    }
}
