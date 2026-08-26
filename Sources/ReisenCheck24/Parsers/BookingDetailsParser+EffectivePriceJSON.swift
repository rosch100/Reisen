import Foundation

extension BookingDetailsParser {
    func effectivePriceFromJSON(html: String, amountPatternFlexible: String) -> Double? {
        // SSOT aus eingebettetem JSON: immer den Zimmerpreis ("effectivePrice") nehmen.
        // Hintergrund: Der Chooser-Text "effektiver Preis: <Betrag>" kann (bei Multi-Room) zuerst den Basket-Total zeigen.
        let effectivePriceJsonPattern =
            #"\"effectivePrice\"\s*:\s*\{\s*\"amount\"\s*:\s*"# + amountPatternFlexible + #""#
        guard let raw = firstRegexMatch(pattern: effectivePriceJsonPattern, in: html) else { return nil }
        return parseAmountText(raw)
    }
}
