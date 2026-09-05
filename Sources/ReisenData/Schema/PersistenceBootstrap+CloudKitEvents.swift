import Foundation
import CoreData
import CloudKit

public enum CloudKitAwaitResult: Sendable, Equatable {
    case completed
    case timedOut
    case disabled
}

extension PersistenceBootstrap {
    /// Waits for a CloudKit export event after local deletes, so wipe-before-reset can propagate.
    /// No-ops when `cloudKitEnabled` is false. Times out so offline devices still recover (caller logs).
    @discardableResult
    public static func awaitCloudKitExportIfNeeded(
        timeout: Duration = .seconds(20),
        cloudKitEnabled: Bool
    ) async -> CloudKitAwaitResult {
        await awaitCloudKitEvent(type: .export, timeout: timeout, cloudKitEnabled: cloudKitEnabled)
    }

    /// Waits for a CloudKit import after reopening an empty store (needed before wipe-from-failed).
    @discardableResult
    public static func awaitCloudKitImportIfNeeded(
        timeout: Duration = .seconds(20),
        cloudKitEnabled: Bool
    ) async -> CloudKitAwaitResult {
        await awaitCloudKitEvent(type: .import, timeout: timeout, cloudKitEnabled: cloudKitEnabled)
    }

    /// Account status for Settings UX (`CKContainer` for `cloudKitContainerID`).
    /// Pass the Effective CloudKit flag (Env × preference) from the caller.
    public static func fetchCloudKitAccountStatus(cloudKitEnabled: Bool) async -> CKAccountStatus {
        guard cloudKitEnabled else { return .couldNotDetermine }
        do {
            return try await CKContainer(identifier: cloudKitContainerID).accountStatus()
        } catch {
            return .couldNotDetermine
        }
    }

    static func awaitCloudKitEvent(
        type: NSPersistentCloudKitContainer.EventType,
        timeout: Duration,
        cloudKitEnabled: Bool
    ) async -> CloudKitAwaitResult {
        guard cloudKitEnabled else { return .disabled }

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                let notifications = NotificationCenter.default.notifications(
                    named: NSPersistentCloudKitContainer.eventChangedNotification
                )
                for await notification in notifications {
                    guard
                        let event = notification.userInfo?[
                            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                        ] as? NSPersistentCloudKitContainer.Event
                    else { continue }
                    if event.type == type, event.endDate != nil {
                        return true
                    }
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first ? .completed : .timedOut
        }
    }
}
