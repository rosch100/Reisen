import Foundation

public struct SyncProviderBookingsResult: Equatable, Sendable {
    public var bookingsPersisted: Int
    public var deadlinesPersisted: Int

    public init(bookingsPersisted: Int, deadlinesPersisted: Int) {
        self.bookingsPersisted = bookingsPersisted
        self.deadlinesPersisted = deadlinesPersisted
    }
}

public enum SyncProviderBookingsError: LocalizedError, Equatable, Sendable {
    case noBookingsFound
    case noDeadlinesFound(foundBookings: Int)

    public var errorDescription: String? {
        switch self {
        case .noBookingsFound:
            return L10n.string(.sync_resultNoBookings)
        case .noDeadlinesFound(let foundBookings):
            return L10n.format(.sync_resultNoDeadlines, foundBookings)
        }
    }
}
