import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingResolve {
    static func findExisting(for booking: Booking, in context: ModelContext) throws -> SDBooking? {
        if let existing = try SwiftDataBookingFind.byID(booking.id, in: context) {
            return existing
        }
        if let url = booking.externalUrl,
           let existingByURL = try SwiftDataBookingFind.byExternalURL(
             url,
             providerRaw: booking.provider.rawValue,
             in: context
           ) {
            return existingByURL
        }
        if let fingerprint = booking.rawPayloadFingerprint,
           let existingByFingerprint = try SwiftDataBookingFind.byFingerprint(
             fingerprint,
             providerRaw: booking.provider.rawValue,
             in: context
           ) {
            return existingByFingerprint
        }
        return nil
    }

    static func insertNew(_ booking: Booking, in context: ModelContext) -> SDBooking {
        let model = SDBooking(
            id: booking.id,
            providerRaw: booking.provider.rawValue,
            bookingTypeRaw: booking.bookingType.rawValue,
            startAt: booking.startAt,
            endAt: booking.endAt,
            statusRaw: booking.status.rawValue
        )
        context.insert(model)
        return model
    }
}
