import Foundation

/// Mappt einen Provider-Draft auf eine bestehende/neue Booking-Entity (SSOT).
public enum SyncBookingDraftApplier {
    public static func apply(
        draft: ProviderBookingDraft,
        onto matched: Booking?,
        now: Date
    ) -> (booking: Booking, deadlinesAdded: Int) {
        var booking = matched ?? Booking(
            provider: draft.provider,
            bookingType: draft.bookingType,
            startAt: draft.startAt,
            endAt: draft.endAt
        )

        SyncBookingDraftFieldCopy.applyCoreFields(from: draft, onto: &booking, now: now)
        let deadlinesAdded = SyncBookingDraftFieldCopy.applyDeadlinesAndRate(from: draft, onto: &booking)
        booking.timesNormalized = false
        return (booking, deadlinesAdded)
    }
}
