import Foundation
import SwiftData
import ReisenDomain

/// SSOT-Einstieg: nach Trip-Mutationen Auto-Gaps reconcilen (leere Menge = no-op).
public enum AutoGapReconcileTrigger {
    public static func run(tripIDs: Set<UUID>, in context: ModelContext) throws {
        guard !tripIDs.isEmpty else { return }
        for tripID in tripIDs {
            try SwiftDataAutoGapReconciler.reconcile(tripID: tripID, in: context)
        }
    }
}
