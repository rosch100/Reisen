import Foundation

extension SyncProviderBookingsResult {
    public func persistedSyncStatusLine(missingDeadlinesHint: Bool) -> String {
        if missingDeadlinesHint {
            return L10n.format(.syncResultCompletedMissingDeadlines, bookingsPersisted)
        }
        return L10n.format(.syncResultCompleted, bookingsPersisted, deadlinesPersisted)
    }
}
