import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataCancellationDeadlineLinkRepository: CancellationDeadlineLinkRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [CancellationDeadlineLink] {
        try modelContext.fetch(FetchDescriptor<SDCancellationDeadlineLink>()).map(DomainMapper.cancellationDeadlineLink(from:))
    }

    public func fetchLinks(forTripID tripID: UUID) throws -> [CancellationDeadlineLink] {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.cancellationDeadlineLink(from:))
    }

    public func fetchLinks(forCancellationDeadlineID deadlineID: UUID) throws -> [CancellationDeadlineLink] {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.cancellationDeadlineID == deadlineID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.cancellationDeadlineLink(from:))
    }

    public func upsert(_ link: CancellationDeadlineLink) throws {
        try SwiftDataCancellationDeadlineLinkUpsert.upsert(link, in: modelContext)
    }

    public func deleteLinks(forTripID tripID: UUID) throws {
        try SwiftDataCancellationDeadlineLinkDelete.deleteLinks(forTripID: tripID, in: modelContext)
    }

    public func deleteLinks(forCancellationDeadlineID deadlineID: UUID) throws {
        try SwiftDataCancellationDeadlineLinkDelete.deleteLinks(
            forCancellationDeadlineID: deadlineID,
            in: modelContext
        )
    }

    public func deleteLinks(ids: [UUID]) throws {
        try SwiftDataCancellationDeadlineLinkDelete.deleteLinks(ids: ids, in: modelContext)
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
