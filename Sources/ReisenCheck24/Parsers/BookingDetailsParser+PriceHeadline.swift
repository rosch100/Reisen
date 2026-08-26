import Foundation

extension BookingDetailsParser {
    func totalPriceHeadlineSeparated(html: String, amountPattern: String) -> Double? {
        // Headline getrennt vom Wert (mit beliebigen Tags dazwischen)
        let headlineSeparatedPattern =
            #"(?:(?:effektiver\s+Preis)|(?:Gesamtpreis)|(?:Gesamtsumme)|(?:Total)|(?:Total\s*Price))[^0-9]{0,250}"# + amountPattern + #"\s*(?:€|EUR)"#
        guard let raw = firstRegexMatch(pattern: headlineSeparatedPattern, in: html) else { return nil }
        return parseAmountText(raw)
    }
}
