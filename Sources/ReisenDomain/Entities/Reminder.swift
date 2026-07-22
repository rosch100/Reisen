import Foundation

public struct Reminder: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var target: ReminderTarget
    public var channel: ReminderChannel
    public var status: ReminderStatus
    public var fireAt: Date
    public var title: String?
    public var notes: String?
    public var cancellationDeadlineID: UUID?
    public var gapID: UUID?
    public var externalAlarmId: String?

    public init(
        id: UUID = UUID(),
        fireAt: Date,
        target: ReminderTarget = .custom,
        channel: ReminderChannel = .notification,
        status: ReminderStatus = .scheduled,
        title: String? = nil,
        notes: String? = nil,
        cancellationDeadlineID: UUID? = nil,
        gapID: UUID? = nil,
        externalAlarmId: String? = nil
    ) {
        self.id = id
        self.fireAt = fireAt
        self.target = target
        self.channel = channel
        self.status = status
        self.title = title
        self.notes = notes
        self.cancellationDeadlineID = cancellationDeadlineID
        self.gapID = gapID
        self.externalAlarmId = externalAlarmId
    }
}
