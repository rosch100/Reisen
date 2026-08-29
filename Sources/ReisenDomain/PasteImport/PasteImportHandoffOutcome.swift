import Foundation

/// Ergebnis eines Konsumversuchs der Share-Übergabe.
///
/// Die Unterscheidung trägt die Meldung: „nichts da“ ist der Normalfall jeder App-Aktivierung,
/// „verloren“ heißt, dass eine bereitliegende Übergabe nicht mehr zu lesen war.
public enum PasteImportHandoffOutcome: Equatable, Sendable {
    /// Eine Übergabe lag bereit und wurde gelesen.
    case payload(PasteImportSource)
    /// Keine Übergabe erreichbar: es lag nichts bereit oder die Ablage existiert gar nicht.
    case noPayload
    /// Eine bereitliegende Übergabe ließ sich nicht lesen; sie ist verloren.
    case lostPayload
}
