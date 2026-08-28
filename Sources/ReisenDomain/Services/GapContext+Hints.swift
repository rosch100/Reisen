import Foundation

extension GapContext {
    /// Ort für Hotel-/Erlebnis-Suche (Ankunft der vorherigen bzw. Ort der nächsten Buchung).
    public var destinationHint: String? {
        Self.firstNonEmpty(fromLocationTo, toLocationFrom, toLocationTo)
    }

    /// Abflug-Hinweis für Flugsuche.
    public var flightFromHint: String? {
        Self.firstNonEmpty(fromLocationTo, fromLocationFrom)
    }

    /// Ankunfts-Hinweis für Flugsuche.
    public var flightToHint: String? {
        Self.firstNonEmpty(toLocationFrom, toLocationTo)
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
