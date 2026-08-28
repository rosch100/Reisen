import Foundation
import ReisenDomain

extension Check24DeepLinkBuilder {
    func flightSearchToken(from hint: String) -> String? {
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1) 3-letter IATA bevorzugen (z.B. "Frankfurt (FRA)" → FRA).
        //    Wichtig: Stadt-Namen wie "Yogyakarta" dürfen nicht fälschlich als "YOG" erkannt werden.
        if let iata = GapDeepLinkText.firstIATA(in: trimmed) {
            return iata
        }

        // 2) Fallback: Stadtname-Token sanitizen, damit URL(string:) nicht an Leerzeichen scheitert.
        return sanitizeFlightSearchToken(trimmed)
    }
}
