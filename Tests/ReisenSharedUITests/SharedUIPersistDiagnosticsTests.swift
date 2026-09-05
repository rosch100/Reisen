import Foundation
import Testing
import ReisenDiagnostics
import ReisenDomain
import ReisenSharedUI

@Test("SharedUIPersistDiagnostics.makeEvent trägt Persist-Fail-Felder")
func sharedUIPersistDiagnosticsMakeEventFields() {
    let event = SharedUIPersistDiagnostics.makeEvent(
        component: "AssignBookingsSheet",
        operation: "assign_bookings_save",
        error: RepositoryError.persistenceFailed("r5")
    )
    #expect(event.component == "AssignBookingsSheet")
    #expect(event.phase == "persist")
    #expect(event.event == "assign_bookings_save")
    #expect(event.result == .failed)
    #expect(event.visibility == .publicDiagnostic)
    #expect(event.reason?.contains("RepositoryError") == true)
}
