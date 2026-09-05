import Foundation

/// SSOT-Predicates für App-Menü Enable (Sync-All / Single-Trip-Aktionen).
public enum AppMenuCommandAvailability {
    public static func canSyncAll(isSyncing: Bool, hasCandidates: Bool) -> Bool {
        !isSyncing && hasCandidates
    }

    /// Edit / Neue Buchung — nur bei genau einer fokussierten Reise (kein Multi-Select).
    public static func canPerformSingleTripActions(
        hasFocusedTrip: Bool,
        selectedTripCount: Int
    ) -> Bool {
        hasFocusedTrip && selectedTripCount == 1
    }

    public static func canAssignBookings(
        canPerformSingleTripActions: Bool,
        hasOpenBookingCandidates: Bool
    ) -> Bool {
        canPerformSingleTripActions && hasOpenBookingCandidates
    }
}
