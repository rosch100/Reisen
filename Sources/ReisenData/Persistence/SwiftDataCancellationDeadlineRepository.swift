import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataCancellationDeadlineRepository: CancellationDeadlineRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [CancellationDeadline] {
        try modelContext.fetch(FetchDescriptor<SDCancellationDeadline>()).map(DomainMapper.deadline(from:))
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
