import Foundation
import UserNotifications

import ReisenDomain
import ReisenData
import SwiftData

@MainActor
public final class LocalReminderScheduler: ReminderScheduling {
    public enum SchedulerError: LocalizedError {
        case notRunningAsAppBundle
        case authorizationDenied

        public var errorDescription: String? {
            switch self {
            case .notRunningAsAppBundle:
                return "Benachrichtigungen erfordern die App als .app-Bundle (Scripts/run-app.sh)."
            case .authorizationDenied:
                return "Benachrichtigungen wurden nicht autorisiert."
            }
        }
    }

    private let modelContext: ModelContext
    private let reminderRepository: SwiftDataReminderRepository

    private struct ReminderKey: Hashable {
        let deadlineID: UUID
        let fireAt: Date
    }

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.reminderRepository = SwiftDataReminderRepository(modelContext: modelContext)
    }

    public func scheduleCancellationDeadlines(
        deadlines: [CancellationDeadline],
        bookingTitles: [UUID: String],
        leadTimesDays: [Int]
    ) async throws -> [Reminder] {
        guard Bundle.main.bundleURL.path.hasSuffix(".app") else {
            throw SchedulerError.notRunningAsAppBundle
        }

        let center = UNUserNotificationCenter.current()
        let leadTimes = try normalizedLeadTimes(leadTimesDays)
        try await requestAuthorization(center: center)

        // Nur kostenlose Stornofristen erinnern (Fee-Stufen „ab … € x“ sind keine Cancel-by-Frist).
        let eligibleDeadlines = deadlines.filter { $0.isFreeCancellation }
        let eligibleDeadlineIDs = Set(eligibleDeadlines.map(\.id))
        let desiredKeys = desiredKeys(
            deadlines: eligibleDeadlines,
            leadTimes: leadTimes
        )

        let existing = try reminderRepository.fetchAll()
        let existingCancellationReminders = existing.filter {
            $0.target == .cancellationDeadline && $0.channel == .notification
        }

        let existingByKey = existingRemindersByKey(
            existingCancellationReminders: existingCancellationReminders,
            eligibleDeadlineIDs: eligibleDeadlineIDs
        )

        // 1) Delete unwanted reminders: cancel pending notifications and remove persisted reminders.
        try await deleteUnwantedReminders(
            existingCancellationReminders: existingCancellationReminders,
            eligibleDeadlineIDs: eligibleDeadlineIDs,
            desiredKeys: desiredKeys,
            center: center
        )

        // 2) Upsert desired reminders: keep existing, create missing.
        let created = try await createMissingReminders(
            eligibleDeadlines: eligibleDeadlines,
            leadTimes: leadTimes,
            bookingTitles: bookingTitles,
            desiredKeys: desiredKeys,
            existingByKey: existingByKey,
            center: center
        )

        try reminderRepository.save()
        return created
    }

    private static func formatDeadlineWallClock(_ deadline: CancellationDeadline) -> String {
        let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = tz
        formatter.dateFormat = "d. MMM yyyy HH:mm"
        return formatter.string(from: deadline.deadlineAt)
    }

    private func normalizedLeadTimes(_ leadTimesDays: [Int]) throws -> [Int] {
        let leadTimes = leadTimesDays.sorted().filter { $0 > 0 }
        guard !leadTimes.isEmpty else {
            throw RepositoryError.invalidState("Keine gültigen Vorlaufzeiten konfiguriert.")
        }
        return leadTimes
    }

    private func requestAuthorization(center: UNUserNotificationCenter) async throws {
        let authorization = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard authorization else { throw SchedulerError.authorizationDenied }
    }

    private func desiredKeys(
        deadlines: [CancellationDeadline],
        leadTimes: [Int]
    ) -> Set<ReminderKey> {
        var desiredKeys: Set<ReminderKey> = []
        let now = Date()

        for deadline in deadlines {
            for leadDays in leadTimes {
                guard let fireAt = Calendar.current.date(byAdding: .day, value: -leadDays, to: deadline.deadlineAt) else { continue }
                guard fireAt > now else { continue }
                desiredKeys.insert(ReminderKey(deadlineID: deadline.id, fireAt: fireAt))
            }
        }

        return desiredKeys
    }

    private func existingRemindersByKey(
        existingCancellationReminders: [Reminder],
        eligibleDeadlineIDs: Set<UUID>
    ) -> [ReminderKey: Reminder] {
        var existingByKey: [ReminderKey: Reminder] = [:]

        for reminder in existingCancellationReminders {
            // Orphans (deadline was deleted) must be cleaned up.
            guard let deadlineID = reminder.cancellationDeadlineID,
                  eligibleDeadlineIDs.contains(deadlineID) else { continue }

            let key = ReminderKey(deadlineID: deadlineID, fireAt: reminder.fireAt)
            existingByKey[key] = reminder
        }

        return existingByKey
    }

    private func deleteUnwantedReminders(
        existingCancellationReminders: [Reminder],
        eligibleDeadlineIDs: Set<UUID>,
        desiredKeys: Set<ReminderKey>,
        center: UNUserNotificationCenter
    ) async throws {
        for reminder in existingCancellationReminders {
            let deadlineID = reminder.cancellationDeadlineID

            let shouldKeep: Bool
            if let deadlineID, eligibleDeadlineIDs.contains(deadlineID) {
                shouldKeep = desiredKeys.contains(ReminderKey(deadlineID: deadlineID, fireAt: reminder.fireAt))
            } else {
                shouldKeep = false
            }

            guard !shouldKeep else { continue }

            if let externalAlarmId = reminder.externalAlarmId, !externalAlarmId.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: [externalAlarmId])
            }
            try reminderRepository.deleteByIDs([reminder.id])
        }
    }

    private func createMissingReminders(
        eligibleDeadlines: [CancellationDeadline],
        leadTimes: [Int],
        bookingTitles: [UUID: String],
        desiredKeys: Set<ReminderKey>,
        existingByKey: [ReminderKey: Reminder],
        center: UNUserNotificationCenter
    ) async throws -> [Reminder] {
        var created: [Reminder] = []
        let now = Date()

        for deadline in eligibleDeadlines {
            for leadDays in leadTimes {
                guard let fireAt = Calendar.current.date(byAdding: .day, value: -leadDays, to: deadline.deadlineAt) else { continue }
                guard fireAt > now else { continue }

                let key = ReminderKey(deadlineID: deadline.id, fireAt: fireAt)
                if existingByKey[key] != nil { continue }
                if !desiredKeys.contains(key) { continue }

                let bookingTitle = deadline.bookingID.flatMap { bookingTitles[$0] } ?? "Buchung"
                let untilText = Self.formatDeadlineWallClock(deadline)
                let content = UNMutableNotificationContent()
                content.title = "Stornofrist"
                content.body = "\(bookingTitle): bis zum \(untilText)"
                content.sound = .default

                let triggerDate = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireAt
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)

                let reminder = Reminder(
                    fireAt: fireAt,
                    target: .cancellationDeadline,
                    channel: .notification,
                    status: .scheduled,
                    title: "Stornofrist",
                    notes: bookingTitle,
                    cancellationDeadlineID: deadline.id,
                    externalAlarmId: request.identifier
                )
                try reminderRepository.insert(reminder)
                created.append(reminder)
            }
        }

        return created
    }
}

