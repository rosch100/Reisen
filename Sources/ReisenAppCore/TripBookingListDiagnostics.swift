import Foundation
import ReisenDiagnostics
import ReisenDomain

/// Diagnostic events for trip timeline batch selection actions.
public enum TripBookingListDiagnostics {
    public static let component = "TripBookingList"
    public static let phase = "selection_action"
    public static let removeFromTripBatchEvent = "remove_from_trip_batch"

    public static func removeFromTripBatch(
        result: DiagnosticResult,
        count: Int,
        errorType: String? = nil
    ) -> DiagnosticEvent {
        DiagnosticEvent(
            context: DiagnosticContext.current
                ?? DiagnosticContext(runID: UUID(), providerID: .manual, operation: "trip_booking_list"),
            component: component,
            phase: phase,
            event: removeFromTripBatchEvent,
            result: result,
            errorType: errorType,
            reason: "count=\(count)"
        )
    }
}
