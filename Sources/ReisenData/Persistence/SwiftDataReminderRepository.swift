import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataReminderRepository: ReminderRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [Reminder] {
        try modelContext.fetch(FetchDescriptor<SDReminder>()).map(DomainMapper.reminder(from:))
    }

    public func insert(_ reminder: Reminder) throws {
        let model = SDReminder(
            id: reminder.id,
            fireAt: reminder.fireAt,
            targetRaw: reminder.target.rawValue,
            channelRaw: reminder.channel.rawValue,
            statusRaw: reminder.status.rawValue,
            title: reminder.title,
            notes: reminder.notes,
            cancellationDeadlineID: reminder.cancellationDeadlineID,
            gapID: reminder.gapID,
            externalAlarmId: reminder.externalAlarmId
        )
        modelContext.insert(model)
    }

    public func deleteByIDs(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<SDReminder>(
            predicate: #Predicate {
                ids.contains($0.id)
            }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func deleteByCancellationDeadlineIDs(_ deadlineIDs: [UUID]) throws {
        let deadlineIDSet = Set(deadlineIDs)
        guard !deadlineIDSet.isEmpty else { return }

        let models = try modelContext.fetch(FetchDescriptor<SDReminder>())
        for model in models {
            guard let id = model.cancellationDeadlineID else { continue }
            if deadlineIDSet.contains(id) {
                modelContext.delete(model)
            }
        }
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
