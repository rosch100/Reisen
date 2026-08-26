import Foundation
import SwiftData
import ReisenDomain

/// Resolves an existing SDBooking for upsert (id → external URL → fingerprint) or inserts a new one.
enum SwiftDataBookingResolve {
    static func model(for booking: Booking, in context: ModelContext) throws -> SDBooking {
        if let existing = try findExisting(for: booking, in: context) {
            return existing
        }
        return insertNew(booking, in: context)
    }
}
