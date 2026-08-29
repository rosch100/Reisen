import Foundation
import ReisenDomain

/// Auslöser der Übergabe aus der Share-Extension.
public enum PasteImportHandoffTrigger: Equatable, Sendable {
    /// Die App wurde über `reisen://paste-import` geöffnet.
    case url
    /// Die App ist aktiv geworden und holt eine liegengebliebene Übergabe nach.
    case activation
}

/// Was mit einer Übergabe geschehen soll.
public enum PasteImportHandoffAction: Equatable, Sendable {
    case start(PasteImportSource)
    /// Nichts zu tun — kein Fehler.
    case ignore
    /// Die Übergabe ist verloren und kein Lauf offen: dem Nutzer melden.
    case reportFailure
}

/// Entscheidet, was ein Auslöser der Übergabe bewirkt.
///
/// Beide Auslöser können für dieselbe Übergabe feuern: iOS liefert `reisen://paste-import` und
/// `scenePhase == .active` praktisch gleichzeitig. Wer zuerst kommt, konsumiert die Dateien; der
/// zweite findet nichts mehr. Er darf den bereits laufenden Import dann nicht mit
/// „Übergabe fehlgeschlagen“ überschreiben — deshalb ist das Ergebnis des Konsums allein nicht
/// entscheidend, sondern zusammen mit dem Zustand der Session.
public enum PasteImportHandoffCoordinator {
    /// - Parameters:
    ///   - outcome: Ergebnis eines idempotenten Konsums.
    ///   - isSessionActive: Ein Lauf, eine Meldung oder eine Editor-Warteschlange ist offen.
    public static func action(
        trigger: PasteImportHandoffTrigger,
        outcome: PasteImportHandoffOutcome,
        isSessionActive: Bool
    ) -> PasteImportHandoffAction {
        switch outcome {
        case .payload(let source):
            // Laufender Import / Editor-Warteschlange hat Vorrang vor einer neuen Share-Übergabe.
            return isSessionActive ? .ignore : .start(source)
        case .noPayload:
            return missingPayloadAction(trigger: trigger, isSessionActive: isSessionActive)
        case .lostPayload:
            // Der Konsum löscht die Dateien: der Verlust ist echt und wird gemeldet, solange er
            // nichts überschreibt.
            return isSessionActive ? .ignore : .reportFailure
        }
    }

    /// Ohne Übergabe ist nur das Öffnen per URL ein Fehler — das Aktivieren läuft ins Leere.
    ///
    /// Das gilt auch, wenn die Ablage selbst fehlt: nur die URL behauptet, dass gerade etwas
    /// geteilt wurde, also darf auch nur sie daraus eine Meldung machen.
    private static func missingPayloadAction(
        trigger: PasteImportHandoffTrigger,
        isSessionActive: Bool
    ) -> PasteImportHandoffAction {
        switch trigger {
        case .activation:
            return .ignore
        case .url:
            return isSessionActive ? .ignore : .reportFailure
        }
    }
}
