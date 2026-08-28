import Foundation
import Testing
import ReisenAppCore
import ReisenDomain

private enum HandoffReadError: Error {
    case unreadablePayload
}

private let sharedSource = PasteImportSource.text("ICE 123 Berlin")

@Test func pasteImportHandoff_startsWhenPayloadIsPresent() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            consumed: .success(sharedSource),
            isSessionActive: false
        ) == .start(sharedSource)
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            consumed: .success(sharedSource),
            isSessionActive: false
        ) == .start(sharedSource)
    )
}

@Test func pasteImportHandoff_reportsMissingPayloadOnlyForURLWithoutRun() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            consumed: .success(nil),
            isSessionActive: false
        ) == .reportFailure
    )
}

/// Der andere Auslöser hat die Übergabe schon konsumiert und den Lauf gestartet: kein Fehler.
@Test func pasteImportHandoff_ignoresMissingPayloadWhileSessionIsActive() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            consumed: .success(nil),
            isSessionActive: true
        ) == .ignore
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            consumed: .success(nil),
            isSessionActive: true
        ) == .ignore
    )
}

/// Aktivieren ohne liegende Übergabe ist der Normalfall jeder Rückkehr in die App.
@Test func pasteImportHandoff_ignoresMissingPayloadOnActivation() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            consumed: .success(nil),
            isSessionActive: false
        ) == .ignore
    )
}

@Test func pasteImportHandoff_reportsReadFailureUnlessItWouldOverwriteARun() {
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .activation,
            consumed: .failure(HandoffReadError.unreadablePayload),
            isSessionActive: false
        ) == .reportFailure
    )
    #expect(
        PasteImportHandoffCoordinator.action(
            trigger: .url,
            consumed: .failure(HandoffReadError.unreadablePayload),
            isSessionActive: true
        ) == .ignore
    )
}
