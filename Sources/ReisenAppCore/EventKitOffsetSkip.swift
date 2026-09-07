import Foundation
import ReisenDiagnostics

/// Shared diagnostic for EventKit paths that skip work due to missing hotel offset.
enum EventKitOffsetSkip {
    static func record(component: String, reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "eventkit_side_effect"
                    ),
                    component: component,
                    phase: "timezone",
                    event: "eventkit_offset_skip",
                    result: .skipped,
                    reason: reason,
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
