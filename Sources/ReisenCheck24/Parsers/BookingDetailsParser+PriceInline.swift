import Foundation

extension BookingDetailsParser {
    func totalPriceInlineColon(html: String, amountPattern: String) -> Double? {
        // Klassiker: Label + Doppelpunkt + Betrag
        let inlineColonPattern =
            #"(?:(?:effektiver\s*Preis)|(?:Gesamtpreis)|(?:Gesamtsumme)|(?:Total)|(?:Total\s*Price))\s*:\s*"# + amountPattern + #"\s*(?:€|EUR)"#
        guard let raw = firstRegexMatch(pattern: inlineColonPattern, in: html) else { return nil }
        return parseAmountText(raw)
    }
}
