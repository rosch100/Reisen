import Foundation
import SwiftData

/// Ob zugeordnete Buchungen beim Reise-Löschen erhalten bleiben oder mitgelöscht werden.
public enum TripDeletionBookingPolicy: Sendable {
    /// Buchungen entkoppeln; sie bleiben als offene Buchungen.
    case keepAsOpen
    /// Enthaltene Buchungen mitlöschen (Cascade-Kinder der Buchung inklusive).
    case deleteContained
}

/// Einheitliche Reise-Löschung: Buchungen gemäß Policy, Trip löschen, speichern.
@MainActor
public enum TripDeletion {
    public static func perform(
        trip: SDTrip,
        in context: ModelContext,
        bookings policy: TripDeletionBookingPolicy
    ) throws {
        let assigned = trip.resolvedBookings
        switch policy {
        case .keepAsOpen:
            for booking in assigned {
                booking.trip = nil
            }
        case .deleteContained:
            for booking in assigned {
                context.delete(booking)
            }
        }
        context.delete(trip)
        try context.save()
    }
}
