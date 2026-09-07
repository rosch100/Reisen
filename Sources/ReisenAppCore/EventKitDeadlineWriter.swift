import Foundation
@preconcurrency import EventKit
import ReisenDomain

struct EventKitDeadlineWriterRequest: Sendable {
    var trips: [Trip]
    var bookings: [Booking]
    var deadlines: [CancellationDeadline]
    var bookingTitles: [UUID: String]
    var eventCalendarTitle: String
    var reminderCalendarTitle: String
    var eventCreateIfMissing: Bool
    var reminderCreateIfMissing: Bool
    var calendarTitleMode: CalendarTitleMode
    var leadTimesDays: [Int]
    var existingLinksByTripID: [UUID: [CancellationDeadlineLink]]
}

/// Teilfehler wie bisher: erfolgreiche Trips liefern einen Persist-Plan; Aufrufer speichert Links und wirft danach `cause`.
struct EventKitDeadlinePartialSyncError: Error {
    let plan: CancellationDeadlineSyncPersistPlan
    let cause: Error
}

actor EventKitDeadlineWriter {
    private struct DeadlineLinkKey: Hashable, Sendable {
        let cancellationDeadlineID: UUID
        let leadDays: Int
    }

    private struct DesiredDeadlineLinkInfo: Sendable {
        let linkKey: DeadlineLinkKey
        let booking: Booking
        let deadline: CancellationDeadline
        let fireAt: Date
        let timeZone: TimeZone
        let bookingTitle: String
    }

    private struct PendingUpsert {
        var draft: CancellationDeadlineLink
        var event: EKEvent
        var reminder: EKReminder?
    }

    private struct TripSyncResult {
        var pendingUpserts: [PendingUpsert]
        var deleteIDs: [UUID]
        var eventSaveCount: Int
        var reminderSaveCount: Int
        var needsCommit: Bool
    }

    func syncDeadlines(_ request: EventKitDeadlineWriterRequest) async throws -> CancellationDeadlineSyncPersistPlan {
        let clockStart = ContinuousClock.now
        var upserts: [CancellationDeadlineLink] = []
        var deleteIDs: [UUID] = []
        var eventSaveCount = 0
        var reminderSaveCount = 0
        var firstError: Error?
        var failureCount = 0

        var store = EKEventStore()
        let shouldWriteReminders = try await Self.requestAccess(store: store)

        let bookingsByID = Dictionary(uniqueKeysWithValues: request.bookings.map { ($0.id, $0) })
        let eligible = request.deadlines.filter(\.isFreeCancellation)
        let leadTimes = try LeadTimesDays.requireNonEmpty(request.leadTimesDays)
        let calendarDuration: TimeInterval = 60 * 60

        guard !request.trips.isEmpty, !eligible.isEmpty else {
            return CancellationDeadlineSyncPersistPlan(
                upserts: [],
                deleteIDs: [],
                eventSaveCount: 0,
                reminderSaveCount: 0,
                durationMilliseconds: Self.elapsedMs(since: clockStart)
            )
        }

        for trip in request.trips {
            do {
                let tripResult = try Self.syncOneTrip(
                    trip: trip,
                    store: store,
                    shouldWriteReminders: shouldWriteReminders,
                    bookingsByID: bookingsByID,
                    eligibleDeadlines: eligible,
                    leadTimes: leadTimes,
                    calendarDuration: calendarDuration,
                    request: request,
                    existingLinks: request.existingLinksByTripID[trip.id] ?? []
                )
                if tripResult.needsCommit {
                    try store.commit()
                    upserts.append(contentsOf: Self.linksAfterCommit(tripResult.pendingUpserts))
                }
                deleteIDs.append(contentsOf: tripResult.deleteIDs)
                eventSaveCount += tripResult.eventSaveCount
                reminderSaveCount += tripResult.reminderSaveCount
            } catch {
                if firstError == nil { firstError = error }
                failureCount += 1
                // Uncommittete Saves des fehlgeschlagenen Trips verwerfen.
                store = EKEventStore()
            }
        }

        let plan = CancellationDeadlineSyncPersistPlan(
            upserts: upserts,
            deleteIDs: deleteIDs,
            eventSaveCount: eventSaveCount,
            reminderSaveCount: reminderSaveCount,
            durationMilliseconds: Self.elapsedMs(since: clockStart)
        )

        if failureCount > 0, let firstError {
            throw EventKitDeadlinePartialSyncError(plan: plan, cause: firstError)
        }

        return plan
    }

    private static func linksAfterCommit(_ pending: [PendingUpsert]) -> [CancellationDeadlineLink] {
        pending.map { item in
            var link = item.draft
            link.eventIdentifier = item.event.eventIdentifier
            if let reminder = item.reminder {
                link.reminderIdentifier = reminder.calendarItemIdentifier
            }
            return link
        }
    }

    private static func syncOneTrip(
        trip: Trip,
        store: EKEventStore,
        shouldWriteReminders: Bool,
        bookingsByID: [UUID: Booking],
        eligibleDeadlines: [CancellationDeadline],
        leadTimes: [Int],
        calendarDuration: TimeInterval,
        request: EventKitDeadlineWriterRequest,
        existingLinks: [CancellationDeadlineLink]
    ) throws -> TripSyncResult {
        var pendingUpserts: [PendingUpsert] = []
        var deleteIDs: [UUID] = []
        var eventSaveCount = 0
        var reminderSaveCount = 0
        var needsCommit = false

        let eventCalendarResult = try EventKitCalendarSupport.ensureCalendar(
            named: EventKitCalendarSupport.title(
                for: trip,
                kind: .event,
                calendarTitleMode: request.calendarTitleMode,
                eventCalendarTitle: request.eventCalendarTitle,
                reminderCalendarTitle: request.reminderCalendarTitle
            ),
            kind: .event,
            store: store,
            createIfMissing: request.eventCreateIfMissing,
            saveCalendarCommit: false
        )
        if eventCalendarResult.didCreate { needsCommit = true }
        let eventCalendar = eventCalendarResult.calendar
        let reminderCalendar = try reminderCalendarIfNeeded(
            shouldWriteReminders: shouldWriteReminders,
            trip: trip,
            store: store,
            eventCalendarTitle: request.eventCalendarTitle,
            reminderCalendarTitle: request.reminderCalendarTitle,
            calendarTitleMode: request.calendarTitleMode,
            reminderCreateIfMissing: request.reminderCreateIfMissing,
            didMutate: &needsCommit
        )
        let desiredByKey = buildDesiredDeadlineLinks(
            eligibleDeadlines: eligibleDeadlines,
            bookingsByID: bookingsByID,
            bookingTitles: request.bookingTitles,
            leadTimes: leadTimes,
            trip: trip
        )
        let existingByKey = existingLinksByKey(existingLinks: existingLinks)

        for (_, info) in desiredByKey {
            let existingLink = existingByKey[info.linkKey]
            let existingEvent = existingLink.flatMap { store.event(withIdentifier: $0.eventIdentifier) }
            let event: EKEvent = existingEvent ?? EKEvent(eventStore: store)
            event.title = "Stornofrist: \(info.bookingTitle)"
            event.calendar = eventCalendar
            event.timeZone = info.timeZone
            event.url = BookingExternalURL.browserURL(from: info.booking.externalUrl)
            event.startDate = info.fireAt
            event.endDate = info.fireAt.addingTimeInterval(calendarDuration)

            let deadlineText: String = {
                if let text = CancellationDeadlineWallClock.string(for: info.deadline) {
                    return text
                }
                EventKitOffsetSkip.record(
                    component: "EventKitDeadlineWriter",
                    reason: "format_deadline_missing_hotel_offset"
                )
                return info.deadline.policyText ?? "Stornofrist"
            }()
            event.notes = """
            Reisen: Storno / Stornofrist
            Deadline: \(deadlineText)
            Vorlauf: \(info.linkKey.leadDays) Tage
            Booking: \(info.bookingTitle)
            """

            event.alarms = []
            event.addAlarm(EKAlarm(absoluteDate: info.fireAt))
            try store.save(event, span: .thisEvent, commit: false)
            eventSaveCount += 1
            needsCommit = true

            let reminder = try upsertReminderIfNeeded(
                existingLink: existingLink,
                reminderCalendar: reminderCalendar,
                shouldWriteReminders: shouldWriteReminders,
                store: store,
                info: info,
                deadlineText: deadlineText
            )
            if reminder != nil {
                reminderSaveCount += 1
                needsCommit = true
            }

            pendingUpserts.append(
                PendingUpsert(
                    draft: CancellationDeadlineLink(
                        id: existingLink?.id ?? UUID(),
                        ownerTripID: trip.id,
                        ownerBookingID: info.booking.id,
                        cancellationDeadlineID: info.deadline.id,
                        leadDays: info.linkKey.leadDays,
                        eventIdentifier: event.eventIdentifier,
                        reminderIdentifier: reminder?.calendarItemIdentifier,
                        lastSyncedAt: Date()
                    ),
                    event: event,
                    reminder: reminder
                )
            )
        }

        for link in unwantedLinks(existingLinks: existingLinks, desiredKeys: Set(desiredByKey.keys)) {
            if let event = store.event(withIdentifier: link.eventIdentifier) {
                try store.remove(event, span: .thisEvent, commit: false)
                needsCommit = true
            }
            if let reminderIdentifier = link.reminderIdentifier,
               let reminder = store.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder {
                try store.remove(reminder, commit: false)
                needsCommit = true
            }
            deleteIDs.append(link.id)
        }

        return TripSyncResult(
            pendingUpserts: pendingUpserts,
            deleteIDs: deleteIDs,
            eventSaveCount: eventSaveCount,
            reminderSaveCount: reminderSaveCount,
            needsCommit: needsCommit
        )
    }

    private static func elapsedMs(since start: ContinuousClock.Instant) -> Int {
        max(0, Int((ContinuousClock.now - start) / .milliseconds(1)))
    }

    private static func requestAccess(store: EKEventStore) async throws -> Bool {
        let eventsGranted = try await store.requestEventAccess()
        guard eventsGranted else { throw LocalEventKitBridgeError.accessDenied }
        return try await store.requestReminderAccess()
    }

    private static func reminderCalendarIfNeeded(
        shouldWriteReminders: Bool,
        trip: Trip,
        store: EKEventStore,
        eventCalendarTitle: String,
        reminderCalendarTitle: String,
        calendarTitleMode: CalendarTitleMode,
        reminderCreateIfMissing: Bool,
        didMutate: inout Bool
    ) throws -> EKCalendar? {
        guard shouldWriteReminders else { return nil }
        let result = try EventKitCalendarSupport.ensureCalendar(
            named: EventKitCalendarSupport.title(
                for: trip,
                kind: .reminder,
                calendarTitleMode: calendarTitleMode,
                eventCalendarTitle: eventCalendarTitle,
                reminderCalendarTitle: reminderCalendarTitle
            ),
            kind: .reminder,
            store: store,
            createIfMissing: reminderCreateIfMissing,
            saveCalendarCommit: false
        )
        if result.didCreate { didMutate = true }
        return result.calendar
    }

    private static func buildDesiredDeadlineLinks(
        eligibleDeadlines: [CancellationDeadline],
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String],
        leadTimes: [Int],
        trip: Trip
    ) -> [DeadlineLinkKey: DesiredDeadlineLinkInfo] {
        var desiredByKey: [DeadlineLinkKey: DesiredDeadlineLinkInfo] = [:]

        for deadline in eligibleDeadlines {
            guard let bookingID = deadline.bookingID,
                  let booking = bookingsByID[bookingID],
                  booking.tripID == trip.id else { continue }

            let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
            guard let tz else {
                EventKitOffsetSkip.record(
                    component: "EventKitDeadlineWriter",
                    reason: "deadline_missing_hotel_offset"
                )
                continue
            }
            let bookingTitle = bookingTitles[bookingID] ?? "Buchung"

            for leadDays in leadTimes {
                guard let fireAt = Calendar.current.date(byAdding: .day, value: -leadDays, to: deadline.deadlineAt) else {
                    continue
                }
                guard fireAt > Date() else { continue }

                let key = DeadlineLinkKey(cancellationDeadlineID: deadline.id, leadDays: leadDays)
                desiredByKey[key] = DesiredDeadlineLinkInfo(
                    linkKey: key,
                    booking: booking,
                    deadline: deadline,
                    fireAt: fireAt,
                    timeZone: tz,
                    bookingTitle: bookingTitle
                )
            }
        }

        return desiredByKey
    }

    private static func existingLinksByKey(
        existingLinks: [CancellationDeadlineLink]
    ) -> [DeadlineLinkKey: CancellationDeadlineLink] {
        var existingByKey: [DeadlineLinkKey: CancellationDeadlineLink] = [:]
        for link in existingLinks {
            existingByKey[DeadlineLinkKey(
                cancellationDeadlineID: link.cancellationDeadlineID,
                leadDays: link.leadDays
            )] = link
        }
        return existingByKey
    }

    private static func unwantedLinks(
        existingLinks: [CancellationDeadlineLink],
        desiredKeys: Set<DeadlineLinkKey>
    ) -> [CancellationDeadlineLink] {
        existingLinks.filter { link in
            let key = DeadlineLinkKey(
                cancellationDeadlineID: link.cancellationDeadlineID,
                leadDays: link.leadDays
            )
            return !desiredKeys.contains(key)
        }
    }

    private static func upsertReminderIfNeeded(
        existingLink: CancellationDeadlineLink?,
        reminderCalendar: EKCalendar?,
        shouldWriteReminders: Bool,
        store: EKEventStore,
        info: DesiredDeadlineLinkInfo,
        deadlineText: String
    ) throws -> EKReminder? {
        guard shouldWriteReminders, let reminderCalendar else { return nil }

        let reminder: EKReminder
        if let existingLink,
           let reminderIdentifier = existingLink.reminderIdentifier,
           let existingReminder = store.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder {
            reminder = existingReminder
        } else {
            reminder = EKReminder(eventStore: store)
        }

        reminder.calendar = reminderCalendar
        reminder.title = "Stornofrist: \(info.bookingTitle)"
        reminder.notes = "Reisen: Storno / Stornofrist\nDeadline: \(deadlineText)"

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = info.timeZone
        reminder.dueDateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: info.fireAt
        )

        reminder.alarms = []
        reminder.addAlarm(EKAlarm(absoluteDate: info.fireAt))

        try store.save(reminder, commit: false)
        return reminder
    }
}
