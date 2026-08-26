import Foundation

public enum SyncProviderBookingsDeadlineGate {
    public static func assertIfRequired(
        drafts: [ProviderBookingDraft],
        requiresDeadlines: Bool
    ) throws {
        let activeDrafts = drafts.filter { $0.status != .cancelled }
        let activeDeadlines = activeDrafts.reduce(0) { $0 + $1.deadlines.count }
        if requiresDeadlines && !activeDrafts.isEmpty && activeDeadlines == 0 {
            throw SyncProviderBookingsError.noDeadlinesFound(foundBookings: drafts.count)
        }
    }
}
