import Foundation
import ReisenDiagnostics
import ReisenDomain

/// Fail-visible Persist-Diagnostics für SharedUI (Alert bleibt Caller-seitig).
public enum SharedUIPersistDiagnostics {
    public static func recordFailure(
        component: String,
        operation: String,
        error: Error
    ) {
        Task {
            await DiagnosticLogger.shared.record(
                makeEvent(component: component, operation: operation, error: error)
            )
        }
    }

    /// Test-/Caller-SSOT für Event-Felder.
    public static func makeEvent(
        component: String,
        operation: String,
        error: Error
    ) -> DiagnosticEvent {
        DiagnosticEvent(
            context: DiagnosticContext(
                runID: UUID(),
                providerID: .manual,
                operation: operation
            ),
            component: component,
            phase: "persist",
            event: operation,
            result: .failed,
            reason: String(describing: type(of: error)),
            visibility: .publicDiagnostic
        )
    }
}
