import Foundation
@preconcurrency import EventKit

import ReisenDomain
import ReisenData

extension LocalEventKitBridge {
    public func syncPreTravelHints(
        trips: [Trip],
        bookings: [Booking],
        bookingTitles: [UUID: String],
        eventCalendarTitle: String,
        reminderCalendarTitle: String,
        eventCreateIfMissing: Bool,
        reminderCreateIfMissing: Bool,
        calendarTitleMode: CalendarTitleMode,
        leadTimesDays: [Int]
    ) async throws {
        let store = EKEventStore()
        let shouldWriteReminders = try await requestAccess(store: store)
        let linkRepo = try requirePreTravelHintLinkRepository()

        if trips.isEmpty {
            let orphanedLinks = try linkRepo.fetchAll()
            if !orphanedLinks.isEmpty {
                try deleteUnwantedPreTravelLinks(
                    links: orphanedLinks,
                    store: store,
                    linkRepo: linkRepo
                )
                try linkRepo.save()
            }
            return
        }

        let leadTimes = try LeadTimesDays.requireNonEmpty(leadTimesDays)

        let eligibleBookings = bookings.withPreTravelImportantHints()
        let calendarDuration: TimeInterval = 60 * 60
        let now = Date()
        var firstError: Error?
        var failureCount = 0

        for trip in trips {
            do {
                let desiredByKey = PreTravelHintDesiredItems.itemsByKey(
                    tripID: trip.id,
                    bookings: eligibleBookings,
                    bookingTitles: bookingTitles,
                    leadTimes: leadTimes,
                    now: now
                )
                let desiredKeys = Set(desiredByKey.keys)

                let existingLinks = try linkRepo.fetchLinks(forTripID: trip.id)
                let unwantedLinks = unwantedPreTravelLinks(
                    existingLinks: existingLinks,
                    desiredKeys: desiredKeys
                )
                if !unwantedLinks.isEmpty {
                    try deleteUnwantedPreTravelLinks(
                        links: unwantedLinks,
                        store: store,
                        linkRepo: linkRepo
                    )
                }

                guard !desiredByKey.isEmpty else { continue }

                let eventCalendar = try ensureCalendar(
                    named: calendarTitle(
                        for: trip,
                        kind: .event,
                        calendarTitleMode: calendarTitleMode,
                        eventCalendarTitle: eventCalendarTitle,
                        reminderCalendarTitle: reminderCalendarTitle
                    ),
                    kind: .event,
                    store: store,
                    createIfMissing: eventCreateIfMissing
                )

                let reminderCalendar = try reminderCalendarIfNeeded(
                    shouldWriteReminders: shouldWriteReminders,
                    trip: trip,
                    store: store,
                    reminderCalendarTitle: reminderCalendarTitle,
                    calendarTitleMode: calendarTitleMode,
                    reminderCreateIfMissing: reminderCreateIfMissing
                )

                let remainingLinks = try linkRepo.fetchLinks(forTripID: trip.id)
                let existingByKey = existingPreTravelLinksByKey(existingLinks: remainingLinks)

                try upsertDesiredPreTravelLinks(
                    desiredByKey: desiredByKey,
                    existingByKey: existingByKey,
                    trip: trip,
                    store: store,
                    eventCalendar: eventCalendar,
                    reminderCalendar: reminderCalendar,
                    shouldWriteReminders: shouldWriteReminders,
                    calendarDuration: calendarDuration,
                    linkRepo: linkRepo
                )
                try linkRepo.save()
            } catch {
                if firstError == nil { firstError = error }
                failureCount += 1
            }
        }

        try finalizePreTravelHintSync(
            failureCount: failureCount,
            firstError: firstError
        )
    }

    private func requirePreTravelHintLinkRepository() throws -> PreTravelHintLinkRepository {
        guard let preTravelHintLinkRepository else {
            throw RepositoryError.invalidState("PreTravelHintLinkRepository fehlt in LocalEventKitBridge.")
        }
        return preTravelHintLinkRepository
    }

    private func finalizePreTravelHintSync(
        failureCount: Int,
        firstError: Error?
    ) throws {
        if failureCount > 0, let firstError {
            throw firstError
        }
    }

    private func existingPreTravelLinksByKey(
        existingLinks: [PreTravelHintLink]
    ) -> [PreTravelHintKeying.LinkKey: PreTravelHintLink] {
        var existingByKey: [PreTravelHintKeying.LinkKey: PreTravelHintLink] = [:]
        for link in existingLinks {
            existingByKey[PreTravelHintKeying.LinkKey(link: link)] = link
        }
        return existingByKey
    }

    private func upsertDesiredPreTravelLinks(
        desiredByKey: [PreTravelHintKeying.LinkKey: PreTravelHintScheduleItem],
        existingByKey: [PreTravelHintKeying.LinkKey: PreTravelHintLink],
        trip: Trip,
        store: EKEventStore,
        eventCalendar: EKCalendar,
        reminderCalendar: EKCalendar?,
        shouldWriteReminders: Bool,
        calendarDuration: TimeInterval,
        linkRepo: PreTravelHintLinkRepository
    ) throws {
        for (_, info) in desiredByKey {
            let existingLink = existingByKey[info.linkKey]
            let existingEvent = existingLink.flatMap { store.event(withIdentifier: $0.eventIdentifier) }
            let summary = BookingGuestHintSummary.notificationBody(
                bookingTitle: info.bookingTitle,
                hints: info.hints
            )
            let eventNotes = BookingGuestHintSummary.eventNotes(leadDays: info.linkKey.leadDays, summary: summary)
            let reminderNotes = BookingGuestHintSummary.reminderNotes(summary: summary)
            let reminderIsCurrent = preTravelReminderIsCurrent(
                existingLink: existingLink,
                shouldWriteReminders: shouldWriteReminders,
                reminderCalendar: reminderCalendar,
                store: store,
                reminderNotes: reminderNotes
            )

            if existingEvent?.notes == eventNotes, reminderIsCurrent, let existingLink {
                let syncedLink = PreTravelHintLink(
                    id: existingLink.id,
                    ownerTripID: existingLink.ownerTripID,
                    ownerBookingID: existingLink.ownerBookingID,
                    leadDays: existingLink.leadDays,
                    eventIdentifier: existingLink.eventIdentifier,
                    reminderIdentifier: existingLink.reminderIdentifier,
                    lastSyncedAt: Date()
                )
                try linkRepo.upsert(syncedLink)
                continue
            }

            let event: EKEvent = existingEvent ?? EKEvent(eventStore: store)
            event.title = BookingGuestHintSummary.eventTitle(bookingTitle: info.bookingTitle)
            event.calendar = eventCalendar
            event.timeZone = .current
            event.url = info.booking.externalUrl.flatMap { URL(string: $0) }
            event.startDate = info.fireAt
            event.endDate = info.fireAt.addingTimeInterval(calendarDuration)
            event.notes = eventNotes
            event.alarms = []
            event.addAlarm(EKAlarm(absoluteDate: info.fireAt))
            try store.save(event, span: .thisEvent)

            let reminderIdentifier = try upsertPreTravelReminderIfNeeded(
                existingLink: existingLink,
                reminderCalendar: reminderCalendar,
                shouldWriteReminders: shouldWriteReminders,
                store: store,
                info: info,
                reminderNotes: reminderNotes
            )

            let linkID = existingLink?.id ?? UUID()
            let updatedLink = PreTravelHintLink(
                id: linkID,
                ownerTripID: trip.id,
                ownerBookingID: info.booking.id,
                leadDays: info.linkKey.leadDays,
                eventIdentifier: event.eventIdentifier,
                reminderIdentifier: reminderIdentifier,
                lastSyncedAt: Date()
            )
            try linkRepo.upsert(updatedLink)
        }
    }

    private func preTravelReminderIsCurrent(
        existingLink: PreTravelHintLink?,
        shouldWriteReminders: Bool,
        reminderCalendar: EKCalendar?,
        store: EKEventStore,
        reminderNotes: String
    ) -> Bool {
        guard shouldWriteReminders, reminderCalendar != nil else { return true }
        guard let existingLink,
              let reminderIdentifier = existingLink.reminderIdentifier,
              let existingReminder = store.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder
        else { return false }
        return existingReminder.notes == reminderNotes
    }

    private func upsertPreTravelReminderIfNeeded(
        existingLink: PreTravelHintLink?,
        reminderCalendar: EKCalendar?,
        shouldWriteReminders: Bool,
        store: EKEventStore,
        info: PreTravelHintScheduleItem,
        reminderNotes: String
    ) throws -> String? {
        guard shouldWriteReminders, let reminderCalendar else { return nil }

        let reminder: EKReminder
        if let existingLink,
           let reminderIdentifier = existingLink.reminderIdentifier,
           let existingReminder = store.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder,
           existingReminder.notes == reminderNotes {
            return reminderIdentifier
        }

        if let existingLink,
           let reminderIdentifier = existingLink.reminderIdentifier,
           let existingReminder = store.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder {
            reminder = existingReminder
        } else {
            reminder = EKReminder(eventStore: store)
        }

        reminder.calendar = reminderCalendar
        reminder.title = BookingGuestHintSummary.eventTitle(bookingTitle: info.bookingTitle)
        reminder.notes = reminderNotes

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        reminder.dueDateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: info.fireAt
        )

        reminder.alarms = []
        reminder.addAlarm(EKAlarm(absoluteDate: info.fireAt))

        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    private func unwantedPreTravelLinks(
        existingLinks: [PreTravelHintLink],
        desiredKeys: Set<PreTravelHintKeying.LinkKey>
    ) -> [PreTravelHintLink] {
        existingLinks.filter { !desiredKeys.contains(PreTravelHintKeying.LinkKey(link: $0)) }
    }

    private func deleteUnwantedPreTravelLinks(
        links: [PreTravelHintLink],
        store: EKEventStore,
        linkRepo: PreTravelHintLinkRepository
    ) throws {
        for link in links {
            if let event = store.event(withIdentifier: link.eventIdentifier) {
                try store.remove(event, span: .thisEvent)
            }
            if let reminderIdentifier = link.reminderIdentifier,
               let reminder = store.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder {
                try store.remove(reminder, commit: true)
            }
        }
        try linkRepo.deleteLinks(ids: links.map(\.id))
    }
}
