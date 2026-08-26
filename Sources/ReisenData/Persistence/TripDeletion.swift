import Foundation
import SwiftData

/// Einheitliche Reise-Löschung: Buchungen entkoppeln, Trip löschen, speichern.
public enum TripDeletion {
    public static let confirmationMessage =
        "Die Reise wird gelöscht. Zugeordnete Buchungen bleiben als offene Buchungen erhalten."

    public static func perform(trip: SDTrip, in context: ModelContext) throws {
        for booking in trip.resolvedBookings {
            booking.trip = nil
        }
        context.delete(trip)
        try context.save()
    }
}
