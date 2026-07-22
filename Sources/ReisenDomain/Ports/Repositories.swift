import Foundation

public enum RepositoryError: LocalizedError, Sendable {
    case notFound(String)
    case persistenceFailed(String)
    case invalidState(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let detail):
            return "Nicht gefunden: \(detail)"
        case .persistenceFailed(let detail):
            return "Persistenzfehler: \(detail)"
        case .invalidState(let detail):
            return detail
        }
    }
}

@MainActor
public protocol BookingRepository: AnyObject {
    func fetchAll() throws -> [Booking]
    func fetch(id: UUID) throws -> Booking?
    func fetch(provider: ProviderID, from startOfDay: Date) throws -> [Booking]
    func upsert(_ booking: Booking) throws
    func delete(id: UUID) throws
    func deleteProviderBookings(provider: ProviderID, keepingExternalURLs: Set<String>, from startOfDay: Date) throws
    func save() throws
}

@MainActor
public protocol TripRepository: AnyObject {
    func fetchAll() throws -> [Trip]
    func fetch(id: UUID) throws -> Trip?
    func upsert(_ trip: Trip) throws
    func delete(id: UUID) throws
    func assignBooking(bookingID: UUID, toTripID tripID: UUID?) throws
    func save() throws
}

@MainActor
public protocol GapRepository: AnyObject {
    func fetchAll() throws -> [Gap]
    func fetch(identityKey: String) throws -> Gap?
    func upsert(_ gap: Gap) throws
    func delete(id: UUID) throws
    func save() throws
}

@MainActor
public protocol ReminderRepository: AnyObject {
    func fetchAll() throws -> [Reminder]
    func insert(_ reminder: Reminder) throws
    func deleteByIDs(_ ids: [UUID]) throws
    func deleteByCancellationDeadlineIDs(_ deadlineIDs: [UUID]) throws
    func save() throws
}

@MainActor
public protocol CancellationDeadlineRepository: AnyObject {
    func fetchAll() throws -> [CancellationDeadline]
    func save() throws
}

@MainActor
public protocol CalendarEventLinkRepository: AnyObject {
    func fetchAll() throws -> [CalendarEventLink]
    func fetchLinks(forTripID tripID: UUID) throws -> [CalendarEventLink]
    func fetchLinks(forBookingID bookingID: UUID) throws -> [CalendarEventLink]

    func upsert(_ link: CalendarEventLink) throws
    func deleteLinks(forTripID tripID: UUID) throws
    func deleteLinks(forBookingID bookingID: UUID) throws
    func deleteLinks(ids: [UUID]) throws

    func save() throws
}

@MainActor
public protocol CancellationDeadlineLinkRepository: AnyObject {
    func fetchAll() throws -> [CancellationDeadlineLink]
    func fetchLinks(forTripID tripID: UUID) throws -> [CancellationDeadlineLink]
    func fetchLinks(forCancellationDeadlineID deadlineID: UUID) throws -> [CancellationDeadlineLink]

    /// Upsert by logical identity `(cancellationDeadlineID, leadDays)`.
    func upsert(_ link: CancellationDeadlineLink) throws

    func deleteLinks(forTripID tripID: UUID) throws
    func deleteLinks(forCancellationDeadlineID deadlineID: UUID) throws
    func deleteLinks(ids: [UUID]) throws

    func save() throws
}
