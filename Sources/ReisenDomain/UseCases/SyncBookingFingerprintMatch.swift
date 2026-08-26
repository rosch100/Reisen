import Foundation

public enum SyncBookingFingerprintMatch {
    public static func unique(
        draft: ProviderBookingDraft,
        byDateFingerprint: [SyncBookingDateFingerprintKey: [UUID: Booking]],
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> Booking? {
        let fingerprint = SyncBookingDateFingerprint.key(
            for: draft,
            calendar: calendar,
            normalizer: normalizer
        )
        guard let candidates = byDateFingerprint[fingerprint],
              candidates.count == 1,
              let only = candidates.values.first else {
            return nil
        }
        return only
    }
}
