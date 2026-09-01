import Foundation
import ReisenDomain
import ReisenProviders

/// SSOT for Airbnb money amounts in stay/activity payment subtitles.
enum AirbnbMoneyAmount {
    /// Supports EN `"Total cost: €133.15"` / `"€1,234.56"` and DE `"Gesamtkosten: 133,15 €"` / `"1.234,56 €"`.
    static func parse(from subtitle: String) -> Double? {
        let cleaned = normalizeSpaces(subtitle)
        guard let match = cleaned.range(
            of: #"([0-9]+([.,][0-9]{3})*([.,][0-9]{2})|[0-9]+)"#,
            options: .regularExpression
        ) else {
            return nil
        }
        return parseNumberToken(String(cleaned[match]))
    }

    static func currency(from subtitle: String) -> String? {
        let cleaned = normalizeSpaces(subtitle)
        let upper = cleaned.uppercased()
        if upper.contains("EUR") || cleaned.contains("€") {
            return "EUR"
        }
        if upper.contains("GBP") || cleaned.contains("£") {
            return "GBP"
        }
        // Bare "$" is ambiguous (USD/CAD/AUD/…); only accept explicit ISO.
        if upper.contains("USD") {
            return "USD"
        }
        return nil
    }

    /// `requestedCurrency`: Sync-Query-Währung; wenn Subtitle kein Symbol hat, Betrag gilt in dieser Währung.
    static func rateDetails(
        from subtitle: String,
        requestedCurrency: String = ProviderSyncLocale.currency()
    ) -> BookingRateDetails? {
        guard let amount = parse(from: subtitle) else { return nil }
        return BookingRateDetails(
            totalPriceAmount: amount,
            totalPriceCurrency: currency(from: subtitle) ?? requestedCurrency,
            boardType: .unknown,
            lastParsedAt: Date()
        )
    }

    /// Last `,` or `.` is the decimal separator; the other is thousands grouping.
    static func parseNumberToken(_ token: String) -> Double? {
        let comma = token.lastIndex(of: ",")
        let dot = token.lastIndex(of: ".")
        switch (comma, dot) {
        case let (c?, d?) where c > d:
            // DE: 1.234,56
            return Double(
                token
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            )
        case (_?, _?):
            // EN: 1,234.56
            return Double(token.replacingOccurrences(of: ",", with: ""))
        case (_?, nil):
            return Double(token.replacingOccurrences(of: ",", with: "."))
        case (nil, _):
            return Double(token)
        }
    }

    private static func normalizeSpaces(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
