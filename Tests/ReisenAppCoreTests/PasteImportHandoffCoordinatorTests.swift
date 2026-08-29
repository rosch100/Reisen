import Foundation
import Testing
import ReisenAppCore
import ReisenDomain

private let sharedSource = PasteImportSource.text("ICE 123 Berlin")

@Test func pasteImportHandoff_startsWhenPayloadIsPresent() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            outcome: .payload(sharedSource),
            isSessionActive: false
        ) == .start(sharedSource)
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            outcome: .payload(sharedSource),
            isSessionActive: false
        ) == .start(sharedSource)
    )
}

/// Laufender Import hat Vorrang — neue Share-Übergabe darf Session/Queue nicht überschreiben.
@Test func pasteImportHandoff_ignoresPayloadWhileSessionIsActive() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            outcome: .payload(sharedSource),
            isSessionActive: true
        ) == .ignore
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            outcome: .payload(sharedSource),
            isSessionActive: true
        ) == .ignore
    )
}

@Test func pasteImportHandoff_reportsMissingPayloadOnlyForURLWithoutRun() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            outcome: .noPayload,
            isSessionActive: false
        ) == .reportFailure
    )
}

/// Der andere Auslöser hat die Übergabe schon konsumiert und den Lauf gestartet: kein Fehler.
@Test func pasteImportHandoff_ignoresMissingPayloadWhileSessionIsActive() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            outcome: .noPayload,
            isSessionActive: true
        ) == .ignore
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            outcome: .noPayload,
            isSessionActive: true
        ) == .ignore
    )
}

/// Aktivieren ohne liegende Übergabe ist der Normalfall jeder Rückkehr in die App — auch dann,
/// wenn die Ablage gar nicht erreichbar ist und deshalb nie etwas darin liegen kann.
@Test func pasteImportHandoff_ignoresMissingPayloadOnActivation() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            outcome: .noPayload,
            isSessionActive: false
        ) == .ignore
    )
}

@Test func pasteImportHandoff_reportsLostPayloadUnlessItWouldOverwriteARun() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            outcome: .lostPayload,
            isSessionActive: false
        ) == .reportFailure
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            outcome: .lostPayload,
            isSessionActive: false
        ) == .reportFailure
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            outcome: .lostPayload,
            isSessionActive: true
        ) == .ignore
    )
}
