import Foundation
import ReisenDiagnostics

/// Diagnose-Events für Create-Draft-Selektion (alle Einstiegspfade).
enum BookingCreateDraftDiagnostics {
    static func recordSelected(reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "booking_create"
                    ),
                    component: "BookingCreateDraft",
                    phase: "booking_create",
                    event: "create_draft_selected",
                    result: .started,
                    reason: reason,
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
