import Foundation

/// Persists provider catalog drafts into the canonical booking store.
@MainActor
public final class SyncProviderBookings {
    private let bookingRepository: any BookingRepository
    private let normalizer: BookingTimeNormalizer

    public init(
        bookingRepository: any BookingRepository,
        normalizer: BookingTimeNormalizer = BookingTimeNormalizer()
    ) {
        self.bookingRepository = bookingRepository
        self.normalizer = normalizer
    }

    public func execute(
        provider: ProviderID,
        drafts: [ProviderBookingDraft],
        requiresDeadlines: Bool,
        now: Date = Date()
    ) throws -> SyncProviderBookingsResult {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        guard !drafts.isEmpty else {
            return try SyncProviderBookingsEmptyCatalog.reconcile(
                provider: provider,
                bookingRepository: bookingRepository,
                startOfToday: startOfToday
            )
        }

        let existing = try bookingRepository.fetch(provider: provider, from: startOfToday)
        var index = SyncBookingMatchIndex(existing: existing, calendar: calendar)
        let (deadlinesPersisted, keptURLs) = try SyncProviderBookingsUpsertLoop.upsertAll(
            drafts: drafts,
            index: &index,
            calendar: calendar,
            normalizer: normalizer,
            bookingRepository: bookingRepository,
            now: now
        )

        try bookingRepository.deleteProviderBookings(
            provider: provider,
            keepingExternalURLs: keptURLs,
            from: startOfToday
        )
        try bookingRepository.save()
        try SyncProviderBookingsDeadlineGate.assertIfRequired(
            drafts: drafts,
            requiresDeadlines: requiresDeadlines
        )

        return SyncProviderBookingsResult(
            bookingsPersisted: drafts.count,
            deadlinesPersisted: deadlinesPersisted
        )
    }
}
