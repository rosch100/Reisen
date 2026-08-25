import Foundation
import UserNotifications

import ReisenDomain
import ReisenData
import SwiftData

extension LocalReminderScheduler {
    private struct PreTravelKey: Hashable {
        let bookingID: UUID
        let fireAt: Date
    }

    public func schedulePreTravelHints(
        bookings: [Booking],
        leadTimesDays: [Int]
    ) async throws -> [Reminder] {
        guard Bundle.main.bundleURL.path.hasSuffix(".app") else {
            throw SchedulerError.notRunningAsAppBundle
        }

        let center = UNUserNotificationCenter.current()
        let leadTimes = try normalizedLeadTimes(leadTimesDays)
        try await requestAuthorization(center: center)

        let eligible = bookings.filter { booking in
            booking.guestHints.contains { $0.category == .preTravelImportant }
        }
        let eligibleIDs = Set(eligible.map(\.id))
        let desiredKeys = preTravelDesiredKeys(bookings: eligible, leadTimes: leadTimes)

        let existing = try reminderRepository.fetchAll()
        let existingPreTravel = existing.filter {
            $0.target == .preTravelHints && $0.channel == .notification
        }

        var existingByKey: [PreTravelKey: Reminder] = [:]
        for reminder in existingPreTravel {
            guard let bookingID = reminder.bookingID, eligibleIDs.contains(bookingID) else { continue }
            existingByKey[PreTravelKey(bookingID: bookingID, fireAt: reminder.fireAt)] = reminder
        }

        for reminder in existingPreTravel {
            let shouldKeep: Bool
            if let bookingID = reminder.bookingID, eligibleIDs.contains(bookingID) {
                shouldKeep = desiredKeys.contains(PreTravelKey(bookingID: bookingID, fireAt: reminder.fireAt))
            } else {
                shouldKeep = false
            }
            guard !shouldKeep else { continue }
            if let externalAlarmId = reminder.externalAlarmId, !externalAlarmId.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: [externalAlarmId])
            }
            try reminderRepository.deleteByIDs([reminder.id])
        }

        var created: [Reminder] = []
        let now = Date()
        for booking in eligible {
            let hints = booking.guestHints.filter { $0.category == .preTravelImportant }
            guard !hints.isEmpty else { continue }
            let bookingTitle = booking.title ?? "Buchung"
            for leadDays in leadTimes {
                guard let fireAt = Calendar.current.date(byAdding: .day, value: -leadDays, to: booking.startAt)
                else { continue }
                guard fireAt > now else { continue }
                let key = PreTravelKey(bookingID: booking.id, fireAt: fireAt)
                if existingByKey[key] != nil { continue }
                if !desiredKeys.contains(key) { continue }

                let content = UNMutableNotificationContent()
                content.title = GuestHintCategory.preTravelImportant.displayTitle
                content.body = BookingGuestHintSummary.notificationBody(bookingTitle: bookingTitle, hints: hints)
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
                    target: .preTravelHints,
                    channel: .notification,
                    status: .scheduled,
                    title: GuestHintCategory.preTravelImportant.displayTitle,
                    notes: bookingTitle,
                    bookingID: booking.id,
                    externalAlarmId: request.identifier
                )
                try reminderRepository.insert(reminder)
                created.append(reminder)
            }
        }

        try reminderRepository.save()
        return created
    }

    private func preTravelDesiredKeys(bookings: [Booking], leadTimes: [Int]) -> Set<PreTravelKey> {
        var keys: Set<PreTravelKey> = []
        let now = Date()
        for booking in bookings {
            for leadDays in leadTimes {
                guard let fireAt = Calendar.current.date(byAdding: .day, value: -leadDays, to: booking.startAt)
                else { continue }
                guard fireAt > now else { continue }
                keys.insert(PreTravelKey(bookingID: booking.id, fireAt: fireAt))
            }
        }
        return keys
    }
}
