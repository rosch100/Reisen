import Foundation
import SwiftData

/// Einheitliche Buchungs-Löschung: Model entfernen und speichern.
@MainActor
public enum BookingDeletion {
    public static func perform(booking: SDBooking, in context: ModelContext) throws {
        context.delete(booking)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
