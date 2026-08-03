import Foundation
import SwiftData

/// Device-local reminder schedule state (includes EventKit/UserNotifications alarm IDs).
@Model
public final class SDReminder {
    public var id: UUID = UUID()
    public var targetRaw: String = ""
    public var channelRaw: String = ""
    public var statusRaw: String = ""
    public var fireAt: Date = Date(timeIntervalSince1970: 0)
    public var title: String?
    public var notes: String?
    /// Soft reference into the cloud store (no cross-store relationship).
    public var cancellationDeadlineID: UUID?
    /// Soft reference into the cloud store (no cross-store relationship).
    public var gapID: UUID?
    public var externalAlarmId: String?

    public init(
        id: UUID = UUID(),
        fireAt: Date,
        targetRaw: String,
        channelRaw: String,
        statusRaw: String,
        title: String? = nil,
        notes: String? = nil,
        cancellationDeadlineID: UUID? = nil,
        gapID: UUID? = nil,
        externalAlarmId: String? = nil
    ) {
        self.id = id
        self.fireAt = fireAt
        self.targetRaw = targetRaw
        self.channelRaw = channelRaw
        self.statusRaw = statusRaw
        self.title = title
        self.notes = notes
        self.cancellationDeadlineID = cancellationDeadlineID
        self.gapID = gapID
        self.externalAlarmId = externalAlarmId
    }
}
