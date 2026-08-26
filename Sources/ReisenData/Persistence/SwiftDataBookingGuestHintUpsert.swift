import Foundation
import SwiftData
import ReisenDomain

public enum SwiftDataBookingGuestHintUpsert {
    public static func upsert(_ hints: [BookingGuestHint], on model: SDBooking, in context: ModelContext) {
        var remaining = model.guestHints ?? []
        var kept: [SDBookingGuestHint] = []

        for hint in hints {
            let sdHint = takeOrCreate(hint, from: &remaining, booking: model, in: context)
            apply(hint, to: sdHint, booking: model)
            kept.append(sdHint)
        }

        SwiftDataBookingMatchHelpers.deleteAll(remaining, in: context)
        model.guestHints = kept
    }

    private static func takeOrCreate(
        _ hint: BookingGuestHint,
        from remaining: inout [SDBookingGuestHint],
        booking: SDBooking,
        in context: ModelContext
    ) -> SDBookingGuestHint {
        if let existing = SwiftDataBookingMatchHelpers.takeMatching(
            from: &remaining,
            id: hint.id,
            idOf: \.id,
            contentMatch: { $0.sourceKey == hint.sourceKey }
        ) {
            return existing
        }
        let created = SDBookingGuestHint(
            id: hint.id,
            booking: booking,
            sourceKey: hint.sourceKey
        )
        context.insert(created)
        return created
    }

    private static func apply(_ hint: BookingGuestHint, to model: SDBookingGuestHint, booking: SDBooking) {
        model.booking = booking
        model.bookingID = hint.bookingID ?? booking.id
        model.categoryRaw = hint.category.rawValue
        model.title = hint.title
        model.detail = hint.detail
        model.sourceKey = hint.sourceKey
        model.providerRaw = hint.providerRaw
    }
}
