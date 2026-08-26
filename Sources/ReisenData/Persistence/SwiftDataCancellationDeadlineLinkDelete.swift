import Foundation
import SwiftData

enum SwiftDataCancellationDeadlineLinkDelete {
    static func deleteLinks(forTripID tripID: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        try deleteAll(matching: descriptor, in: context)
    }

    static func deleteLinks(forCancellationDeadlineID deadlineID: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.cancellationDeadlineID == deadlineID }
        )
        try deleteAll(matching: descriptor, in: context)
    }

    static func deleteLinks(ids: [UUID], in context: ModelContext) throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        try deleteAll(matching: descriptor, in: context)
    }

    private static func deleteAll(
        matching descriptor: FetchDescriptor<SDCancellationDeadlineLink>,
        in context: ModelContext
    ) throws {
        let models = try context.fetch(descriptor)
        for model in models {
            context.delete(model)
        }
    }
}
