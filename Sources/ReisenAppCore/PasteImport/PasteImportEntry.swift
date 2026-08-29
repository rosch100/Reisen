import Foundation

/// Einstieg in einen Paste-Import; er bestimmt, in welche Reise neue Buchungen fallen.
///
/// Die Reise gehört zum Einstieg, nicht zum App-Zustand: eine im Reise-Tab gewählte Reise bleibt
/// dort ausgewählt, während der Nutzer in „Offen“ arbeitet. Nur `trip` trägt darum eine Reise.
public enum PasteImportEntry: Equatable, Sendable {
    /// Reise-Einstieg mit der dort gewählten Reise; ohne Auswahl entsteht eine offene Buchung.
    case trip(UUID?)
    /// Einstieg in „Offen“: neue Buchungen bleiben offen.
    case open
    /// Übergabe aus der Share-Extension: sie kommt von außen und hat keinen Reise-Kontext.
    case handoff

    public var tripID: UUID? {
        switch self {
        case .trip(let tripID):
            return tripID
        case .open, .handoff:
            return nil
        }
    }
}
