import Foundation
import SwiftData

/// Einheitliche Buchungs-Löschung. Bei Auto-Gap: Suppress → Delete → Reconcile (Spec-Reihenfolge).
@MainActor
public enum BookingDeletion {
    public static func perform(booking: SDBooking, in context: ModelContext) throws {
        let tripID = booking.trip?.id
        let identityKey = booking.autoGapIdentityKey
        let isAutoGap = booking.provider == .autoGap

        if isAutoGap, let tripID, let identityKey, !identityKey.isEmpty {
            try SwiftDataAutoGapReconciler.suppress(
                tripID: tripID,
                identityKey: identityKey,
                in: context
            )
        }

        context.delete(booking)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        if let tripID {
            try AutoGapReconcileTrigger.run(tripIDs: [tripID], in: context)
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }
}
