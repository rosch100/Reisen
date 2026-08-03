import Foundation

extension Check24DeepLinkBuilder {
    func flightSearchToken(from hint: String) -> String? {
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1) 3-letter IATA bevorzugen (z.B. "Frankfurt (FRA)" → FRA).
        //    Wichtig: Stadt-Namen wie "Yogyakarta" dürfen nicht fälschlich als "YOG" erkannt werden.
        if let iata = extractIATAToken(from: trimmed) {
            return iata
        }

        // 2) Fallback: Stadtname-Token sanitizen, damit URL(string:) nicht an Leerzeichen scheitert.
        // Check24 scheint ein Token-Format zu akzeptieren; wenn es abgelehnt wird, kann der Nutzer manuell korrigieren.
        return sanitizeFlightSearchToken(trimmed)
    }
}
