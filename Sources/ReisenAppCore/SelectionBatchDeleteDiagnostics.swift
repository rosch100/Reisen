import Foundation
import ReisenDiagnostics
import ReisenDomain

public enum SelectionBatchDeleteDiagnostics {
    public static let phase = "selection_action"
    public static let deleteBatchEvent = "delete_batch"

    public static func deleteBatch(
        component: String,
        result: DiagnosticResult,
        count: Int,
        errorType: String? = nil
    ) -> DiagnosticEvent {
        DiagnosticEvent(
            context: DiagnosticContext.current
                ?? DiagnosticContext(runID: UUID(), providerID: .manual, operation: "selection_batch_delete"),
            component: component,
            phase: phase,
            event: deleteBatchEvent,
            result: result,
            errorType: errorType,
            reason: "count=\(count)"
        )
    }

    public static func openBookingList(
        result: DiagnosticResult,
        count: Int,
        errorType: String? = nil
    ) -> DiagnosticEvent {
        deleteBatch(component: "OpenBookingList", result: result, count: count, errorType: errorType)
    }

    public static func tripBookingList(
        result: DiagnosticResult,
        count: Int,
        errorType: String? = nil
    ) -> DiagnosticEvent {
        deleteBatch(component: "TripBookingList", result: result, count: count, errorType: errorType)
    }

    public static func tripList(
        result: DiagnosticResult,
        count: Int,
        errorType: String? = nil
    ) -> DiagnosticEvent {
        deleteBatch(component: "TripList", result: result, count: count, errorType: errorType)
    }
}
