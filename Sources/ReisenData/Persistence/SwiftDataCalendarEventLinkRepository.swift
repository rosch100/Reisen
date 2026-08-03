import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataCalendarEventLinkRepository: CalendarEventLinkRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [CalendarEventLink] {
        try modelContext.fetch(FetchDescriptor<SDCalendarEventLink>()).map(DomainMapper.calendarEventLink(from:))
    }

    public func fetchLinks(forTripID tripID: UUID) throws -> [CalendarEventLink] {
        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.calendarEventLink(from:))
    }

    public func fetchLinks(forBookingID bookingID: UUID) throws -> [CalendarEventLink] {
        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate { $0.ownerBookingID == bookingID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.calendarEventLink(from:))
    }

    public func upsert(_ link: CalendarEventLink) throws {
        try SwiftDataCalendarEventLinkUpsert.upsert(link, in: modelContext)
    }

    public func deleteLinks(forTripID tripID: UUID) throws {
        try SwiftDataCalendarEventLinkDelete.deleteLinks(forTripID: tripID, in: modelContext)
    }

    public func deleteLinks(forBookingID bookingID: UUID) throws {
        try SwiftDataCalendarEventLinkDelete.deleteLinks(forBookingID: bookingID, in: modelContext)
    }

    public func deleteLinks(ids: [UUID]) throws {
        try SwiftDataCalendarEventLinkDelete.deleteLinks(ids: ids, in: modelContext)
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
