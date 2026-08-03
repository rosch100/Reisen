import Foundation

@MainActor
public enum SyncProviderBookingsUpsertLoop {
    public static func upsertAll(
        drafts: [ProviderBookingDraft],
        index: inout SyncBookingMatchIndex,
        calendar: Calendar,
        normalizer: BookingTimeNormalizer,
        bookingRepository: any BookingRepository,
        now: Date
    ) throws -> (deadlinesPersisted: Int, keptURLs: Set<String>) {
        var deadlinesPersisted = 0
        var keptURLs = Set<String>()

        for draft in drafts {
            guard let externalUrl = draft.externalUrl else {
                throw RepositoryError.invalidState("Buchung ohne externalUrl kann nicht upserted werden.")
            }
            keptURLs.insert(externalUrl)

            let matched = index.match(
                draft: draft,
                externalUrl: externalUrl,
                calendar: calendar,
                normalizer: normalizer
            )
            var (booking, deadlinesAdded) = SyncBookingDraftApplier.apply(
                draft: draft,
                onto: matched,
                now: now
            )
            deadlinesPersisted += deadlinesAdded
            booking = normalizer.normalizePendingIfPossible(booking)
            try bookingRepository.upsert(booking)
            index.remember(booking, calendar: calendar)
        }

        return (deadlinesPersisted, keptURLs)
    }
}
