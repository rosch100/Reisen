import Foundation

/// Index + Matching für Provider-Sync-Upserts (SSOT).
public struct SyncBookingMatchIndex: Sendable {
    public private(set) var byURL: [String: Booking]
    public private(set) var byConfirmationCode: [String: [UUID: Booking]]
    public private(set) var byDateFingerprint: [SyncBookingDateFingerprintKey: [UUID: Booking]]

    public init(existing: [Booking], calendar: Calendar = .current) {
        var byURL: [String: Booking] = [:]
        var byConfirmationCode: [String: [UUID: Booking]] = [:]
        var byDateFingerprint: [SyncBookingDateFingerprintKey: [UUID: Booking]] = [:]

        for booking in existing {
            SyncBookingIndexInsert.insert(
                booking,
                intoURL: &byURL,
                intoCode: &byConfirmationCode,
                intoFingerprint: &byDateFingerprint,
                calendar: calendar
            )
        }

        self.byURL = byURL
        self.byConfirmationCode = byConfirmationCode
        self.byDateFingerprint = byDateFingerprint
    }

    public mutating func remember(_ booking: Booking, calendar: Calendar) {
        SyncBookingIndexInsert.insert(
            booking,
            intoURL: &byURL,
            intoCode: &byConfirmationCode,
            intoFingerprint: &byDateFingerprint,
            calendar: calendar
        )
    }

    public func match(
        draft: ProviderBookingDraft,
        externalUrl: String,
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> Booking? {
        SyncBookingMatchLookup.match(
            draft: draft,
            externalUrl: externalUrl,
            byURL: byURL,
            byConfirmationCode: byConfirmationCode,
            byDateFingerprint: byDateFingerprint,
            calendar: calendar,
            normalizer: normalizer
        )
    }
}
