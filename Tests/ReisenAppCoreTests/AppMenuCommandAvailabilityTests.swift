import Testing
@testable import ReisenAppCore

struct AppMenuCommandAvailabilityTests {
    @Test func canSyncAllWhenIdleWithCandidates() {
        #expect(AppMenuCommandAvailability.canSyncAll(isSyncing: false, hasCandidates: true))
    }

    @Test(arguments: [
        (true, true),
        (false, false),
        (true, false),
    ])
    func canSyncAllFalseWhenBusyOrEmpty(isSyncing: Bool, hasCandidates: Bool) {
        #expect(!AppMenuCommandAvailability.canSyncAll(isSyncing: isSyncing, hasCandidates: hasCandidates))
    }

    @Test func singleTripActionsRequireFocusedTripAndCountOne() {
        #expect(
            AppMenuCommandAvailability.canPerformSingleTripActions(
                hasFocusedTrip: true,
                selectedTripCount: 1
            )
        )
    }

    @Test(arguments: [
        (false, 1),
        (true, 0),
        (true, 2),
    ])
    func singleTripActionsDisabledWithoutExactSingleSelection(
        hasFocusedTrip: Bool,
        selectedTripCount: Int
    ) {
        #expect(
            !AppMenuCommandAvailability.canPerformSingleTripActions(
                hasFocusedTrip: hasFocusedTrip,
                selectedTripCount: selectedTripCount
            )
        )
    }

    @Test func assignRequiresTripActionsAndCandidates() {
        #expect(
            AppMenuCommandAvailability.canAssignBookings(
                canPerformSingleTripActions: true,
                hasOpenBookingCandidates: true
            )
        )
        #expect(
            !AppMenuCommandAvailability.canAssignBookings(
                canPerformSingleTripActions: true,
                hasOpenBookingCandidates: false
            )
        )
        #expect(
            !AppMenuCommandAvailability.canAssignBookings(
                canPerformSingleTripActions: false,
                hasOpenBookingCandidates: true
            )
        )
    }
}
