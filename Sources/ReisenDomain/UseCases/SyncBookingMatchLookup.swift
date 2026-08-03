import Foundation

public enum SyncBookingMatchLookup {
    public static func match(
        draft: ProviderBookingDraft,
        externalUrl: String,
        byURL: [String: Booking],
        byConfirmationCode: [String: [UUID: Booking]],
        byDateFingerprint: [SyncBookingDateFingerprintKey: [UUID: Booking]],
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> Booking? {
        if let byURL = byURL[externalUrl] {
            return byURL
        }

        if let only = uniqueByConfirmationCode(
            draft.confirmationCode,
            in: byConfirmationCode
        ) {
            return only
        }

        return SyncBookingFingerprintMatch.unique(
            draft: draft,
            byDateFingerprint: byDateFingerprint,
            calendar: calendar,
            normalizer: normalizer
        )
    }

    private static func uniqueByConfirmationCode(
        _ code: String?,
        in byConfirmationCode: [String: [UUID: Booking]]
    ) -> Booking? {
        guard let code, !code.isEmpty,
              let candidatesByCode = byConfirmationCode[code],
              candidatesByCode.count == 1,
              let only = candidatesByCode.values.first else {
            return nil
        }
        return only
    }
}
