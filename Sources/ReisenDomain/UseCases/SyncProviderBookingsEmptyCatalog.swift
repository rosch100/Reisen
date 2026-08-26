import Foundation

@MainActor
public enum SyncProviderBookingsEmptyCatalog {
    public static func reconcile(
        provider: ProviderID,
        bookingRepository: any BookingRepository,
        startOfToday: Date
    ) throws -> SyncProviderBookingsResult {
        try bookingRepository.deleteProviderBookings(
            provider: provider,
            keepingExternalURLs: [],
            from: startOfToday
        )
        try bookingRepository.save()
        return SyncProviderBookingsResult(bookingsPersisted: 0, deadlinesPersisted: 0)
    }
}
