import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataPreTravelHintLinkRepository: PreTravelHintLinkRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [PreTravelHintLink] {
        try modelContext.fetch(FetchDescriptor<SDPreTravelHintLink>()).map(DomainMapper.preTravelHintLink(from:))
    }

    public func fetchLinks(forTripID tripID: UUID) throws -> [PreTravelHintLink] {
        let descriptor = FetchDescriptor<SDPreTravelHintLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.preTravelHintLink(from:))
    }

    public func fetchLinks(forBookingID bookingID: UUID) throws -> [PreTravelHintLink] {
        let descriptor = FetchDescriptor<SDPreTravelHintLink>(
            predicate: #Predicate { $0.ownerBookingID == bookingID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.preTravelHintLink(from:))
    }

    public func upsert(_ link: PreTravelHintLink) throws {
        try SwiftDataPreTravelHintLinkUpsert.upsert(link, in: modelContext)
    }

    public func deleteLinks(forTripID tripID: UUID) throws {
        try SwiftDataPreTravelHintLinkDelete.deleteLinks(forTripID: tripID, in: modelContext)
    }

    public func deleteLinks(forBookingID bookingID: UUID) throws {
        try SwiftDataPreTravelHintLinkDelete.deleteLinks(forBookingID: bookingID, in: modelContext)
    }

    public func deleteLinks(ids: [UUID]) throws {
        try SwiftDataPreTravelHintLinkDelete.deleteLinks(ids: ids, in: modelContext)
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
