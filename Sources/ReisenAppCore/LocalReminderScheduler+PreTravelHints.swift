import Foundation
import UserNotifications

import ReisenDomain
import ReisenData
import SwiftData

extension LocalReminderScheduler {
    public func schedulePreTravelHints(
        bookings: [Booking],
        bookingTitles: [UUID: String],
        leadTimesDays: [Int]
    ) async throws -> [Reminder] {
        guard Bundle.main.bundleURL.path.hasSuffix(".app") else {
            throw SchedulerError.notRunningAsAppBundle
        }

        let center = UNUserNotificationCenter.current()
        let leadTimes = try normalizedLeadTimes(leadTimesDays)
        try await requestAuthorization(center: center)

        let eligible = bookings.withPreTravelImportantHints()
        let eligibleIDs = Set(eligible.map(\.id))
        let now = Date()
        let desiredKeys = PreTravelHintKeying.notificationDesiredKeys(
            bookings: eligible,
            bookingTitles: bookingTitles,
            leadTimes: leadTimes,
            now: now
        )

        let existing = try reminderRepository.fetchAll()
        let existingPreTravel = existing.filter {
            $0.target == .preTravelHints && $0.channel == .notification
        }

        var existingByKey = existingPreTravelRemindersByKey(
            existingPreTravel: existingPreTravel,
            eligibleBookingIDs: eligibleIDs
        )

        try await deleteUnwantedPreTravelReminders(
            existingPreTravel: existingPreTravel,
            eligibleBookingIDs: eligibleIDs,
            desiredKeys: desiredKeys,
            center: center,
            existingByKey: &existingByKey
        )

        let created = try await upsertPreTravelReminders(
            eligible: eligible,
            bookingTitles: bookingTitles,
            leadTimes: leadTimes,
            desiredKeys: desiredKeys,
            existingByKey: existingByKey,
            now: now,
            center: center
        )

        try reminderRepository.save()
        return created
    }

    private func existingPreTravelRemindersByKey(
        existingPreTravel: [Reminder],
        eligibleBookingIDs: Set<UUID>
    ) -> [PreTravelHintKeying.NotificationKey: Reminder] {
        var existingByKey: [PreTravelHintKeying.NotificationKey: Reminder] = [:]
        for reminder in existingPreTravel {
            guard let bookingID = reminder.bookingID,
                  eligibleBookingIDs.contains(bookingID) else { continue }
            let key = PreTravelHintKeying.NotificationKey(bookingID: bookingID, fireAt: reminder.fireAt)
            existingByKey[key] = reminder
        }
        return existingByKey
    }

    private func deleteUnwantedPreTravelReminders(
        existingPreTravel: [Reminder],
        eligibleBookingIDs: Set<UUID>,
        desiredKeys: Set<PreTravelHintKeying.NotificationKey>,
        center: UNUserNotificationCenter,
        existingByKey: inout [PreTravelHintKeying.NotificationKey: Reminder]
    ) async throws {
        for reminder in existingPreTravel {
            let shouldKeep: Bool
            if let key = PreTravelHintKeying.NotificationKey(reminder: reminder),
               eligibleBookingIDs.contains(key.bookingID) {
                shouldKeep = desiredKeys.contains(key)
            } else {
                shouldKeep = false
            }
            guard !shouldKeep else { continue }

            removePendingNotification(for: reminder, center: center)
            try reminderRepository.deleteByIDs([reminder.id])
            if let key = PreTravelHintKeying.NotificationKey(reminder: reminder) {
                existingByKey.removeValue(forKey: key)
            }
        }
    }

    private func upsertPreTravelReminders(
        eligible: [Booking],
        bookingTitles: [UUID: String],
        leadTimes: [Int],
        desiredKeys: Set<PreTravelHintKeying.NotificationKey>,
        existingByKey: [PreTravelHintKeying.NotificationKey: Reminder],
        now: Date,
        center: UNUserNotificationCenter
    ) async throws -> [Reminder] {
        var created: [Reminder] = []
        let displayTitle = GuestHintCategory.preTravelImportant.displayTitle
        let notificationItems = PreTravelHintNotificationItems.items(
            bookings: eligible,
            bookingTitles: bookingTitles,
            leadTimes: leadTimes,
            now: now
        )

        for item in notificationItems {
            guard desiredKeys.contains(item.notificationKey) else { continue }

            let fingerprint = BookingGuestHintSummary.contentFingerprint(hints: item.hints)
            let body = BookingGuestHintSummary.notificationBody(
                bookingTitle: item.bookingTitle,
                hints: item.hints
            )

            if let existing = existingByKey[item.notificationKey] {
                if existing.notes == fingerprint { continue }
                removePendingNotification(for: existing, center: center)
                try reminderRepository.deleteByIDs([existing.id])
            }

            let request = try await scheduleNotification(
                title: displayTitle,
                body: body,
                fireAt: item.fireAt,
                center: center
            )

            let reminder = Reminder(
                fireAt: item.fireAt,
                target: .preTravelHints,
                channel: .notification,
                status: .scheduled,
                title: displayTitle,
                notes: fingerprint,
                bookingID: item.booking.id,
                externalAlarmId: request.identifier
            )
            try reminderRepository.insert(reminder)
            created.append(reminder)
        }

        return created
    }

    func removePendingNotification(for reminder: Reminder, center: UNUserNotificationCenter) {
        guard let externalAlarmId = reminder.externalAlarmId, !externalAlarmId.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: [externalAlarmId])
    }

    private func scheduleNotification(
        title: String,
        body: String,
        fireAt: Date,
        center: UNUserNotificationCenter
    ) async throws -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
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
        return request
    }
}
