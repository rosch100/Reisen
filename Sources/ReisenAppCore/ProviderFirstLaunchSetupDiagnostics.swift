import Foundation
import ReisenDiagnostics
import ReisenDomain

/// Shared DiagnosticLogger events for first-launch provider setup (macOS + iOS hosts).
public enum ProviderFirstLaunchSetupDiagnostics: Sendable {
    public static let component = "ProviderFirstLaunchSetup"
    public static let phase = "setup"
    public static let operation = "provider_first_launch_setup"

    public static let presentedEvent = "provider_setup_presented"
    public static let completedEvent = "provider_setup_completed"
    public static let deferredEvent = "provider_setup_deferred"
    public static let skippedEvent = "provider_setup_skipped"

    public static func makeEvent(
        event: String,
        result: DiagnosticResult,
        reason: String
    ) -> DiagnosticEvent {
        DiagnosticEvent(
            context: DiagnosticContext(
                runID: UUID(),
                providerID: .manual,
                operation: operation
            ),
            component: component,
            phase: phase,
            event: event,
            result: result,
            reason: reason
        )
    }

    public static func record(
        event: String,
        result: DiagnosticResult,
        reason: String
    ) {
        let diagnosticEvent = makeEvent(event: event, result: result, reason: reason)
        Task {
            await DiagnosticLogger.shared.record(diagnosticEvent)
        }
    }

    public static func recordPresented(reason: String) {
        record(event: presentedEvent, result: .started, reason: reason)
    }

    public static func recordCompleted(enabledCount: Int) {
        record(
            event: completedEvent,
            result: .succeeded,
            reason: "continue_count_\(enabledCount)"
        )
    }

    public static func recordDeferred() {
        record(event: deferredEvent, result: .cancelled, reason: "later")
    }

    public static func recordSkipped(reason: String) {
        record(event: skippedEvent, result: .skipped, reason: reason)
    }
}
