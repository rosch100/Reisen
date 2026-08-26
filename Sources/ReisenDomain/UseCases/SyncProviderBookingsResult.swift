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
            return "Keine Buchungen gefunden."
        case .noDeadlinesFound(let foundBookings):
            return "Keine Stornofristen gefunden (foundBookings=\(foundBookings))."
        }
    }
}
