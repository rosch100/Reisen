import Foundation

public enum SyncBookingDraftFieldCopy {
    public static func applyCoreFields(from draft: ProviderBookingDraft, onto booking: inout Booking, now: Date) {
        booking.provider = draft.provider
        booking.bookingType = draft.bookingType
        booking.title = draft.title
        booking.confirmationCode = draft.confirmationCode
        booking.externalUrl = draft.externalUrl
        booking.startAt = draft.startAt
        booking.endAt = draft.endAt
        booking.locationFrom = draft.locationFrom
        booking.locationTo = draft.locationTo
        booking.locationFromAddress = draft.locationFromAddress
        booking.locationToAddress = draft.locationToAddress
        booking.status = draft.status
        booking.lastSyncedAt = now
        booking.rawPayloadFingerprint = draft.rawPayloadFingerprint
        booking.passengers = draft.passengers
        booking.guestHints = draft.guestHints
        SyncBookingDraftOffsets.apply(from: draft, onto: &booking)
    }

    public static func applyDeadlinesAndRate(
        from draft: ProviderBookingDraft,
        onto booking: inout Booking
    ) -> Int {
        SyncBookingDraftDeadlines.apply(from: draft, onto: &booking)
    }
}
