import Foundation
import EventKit
import ReisenDomain
import SwiftData
import ReisenData

// EventKit types are not annotated as `Sendable`, but they are main-actor bound in this codebase
// (this bridge is a `@MainActor` type). This prevents Swift 6.2/6.3 "sending risks" build failures.
extension EKEventStore: @unchecked Sendable {}

@MainActor
final class LocalEventKitBridge: CalendarSyncing {
    private let calendarEventLinkRepository: CalendarEventLinkRepository?
    private let cancellationDeadlineLinkRepository: CancellationDeadlineLinkRepository?

    init() {
        self.calendarEventLinkRepository = nil
        self.cancellationDeadlineLinkRepository = nil
    }

    init(modelContext: ModelContext) {
        self.calendarEventLinkRepository = SwiftDataCalendarEventLinkRepository(modelContext: modelContext)
        self.cancellationDeadlineLinkRepository = SwiftDataCancellationDeadlineLinkRepository(modelContext: modelContext)
    }

    enum EventKitError: LocalizedError {
        case accessDenied
        case calendarNotFound
        case calendarModificationDenied
        case calendarWriteFailed
        case reminderAccessDenied
        case reminderWriteFailed
        case reminderCalendarNotFound

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return """
                Kalenderzugriff wurde verweigert.

                Bitte aktiviere unter „Systemeinstellungen → Datenschutz & Sicherheit → Kalender“ für „Reisen“ den Schalter.
                """
            case .calendarNotFound:
                return "Kein Kalender mit dem angegebenen Titel gefunden."
            case .calendarModificationDenied:
                return """
                Der Kalender kann nicht geändert werden.

                Hintergrund: Einige Kalender-Accounts (z. B. Exchange/Google) erlauben eventuell kein Hinzufügen/Entfernen von Kalenderobjekten.

                Bitte prüfe in der Kalender-App bzw. bei deinem Account, ob Reisen das Hinzufügen/Entfernen von Kalendereinträgen darf.
                """
            case .calendarWriteFailed:
                return "Kalender-Synchronisation fehlgeschlagen (Schreiben nicht möglich)."
            case .reminderAccessDenied:
                return "Erinnerungen-Zugriff wurde verweigert."
            case .reminderCalendarNotFound:
                return "Kein Kalender für Erinnerungen gefunden."
            case .reminderWriteFailed:
                return "Erinnerungen-Synchronisation fehlgeschlagen (Schreiben nicht möglich)."
            }
        }
    }

    private struct EventLinkKey: Hashable {
        let role: CalendarEventRole
        let ownerBookingID: UUID?
    }

    private struct DeadlineLinkKey: Hashable {
        let cancellationDeadlineID: UUID
        let leadDays: Int
    }

    private struct DesiredDeadlineLinkInfo {
        let linkKey: DeadlineLinkKey
        let trip: Trip
        let booking: Booking
        let deadline: CancellationDeadline
        let fireAt: Date
        let timeZone: TimeZone
        let bookingTitle: String
    }

    func fetchEventCalendarTitles() async throws -> [String] {
        let store = EKEventStore()
        let granted = try await store.requestEventAccess()
        guard granted else { throw EventKitError.accessDenied }

        return store.calendars(for: .event).map(\.title).sorted()
    }

    func fetchReminderCalendarTitles() async throws -> [String] {
        let store = EKEventStore()
        let granted = try await store.requestReminderAccess()
        guard granted else { throw EventKitError.reminderAccessDenied }

        return store.calendars(for: .reminder).map(\.title).sorted()
    }

    func syncCancellationDeadlines(
        trips: [Trip],
        bookings: [Booking],
        deadlines: [CancellationDeadline],
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
        let linkRepo = try requireCancellationDeadlineLinkRepository()

        if trips.isEmpty || deadlines.isEmpty { return }

        let bookingsByID = Dictionary(uniqueKeysWithValues: bookings.map { ($0.id, $0) })

        let eligibleDeadlines = deadlines.filter { $0.isFreeCancellation }
        guard !eligibleDeadlines.isEmpty else { return }

        let leadTimes = leadTimesDays.sorted().filter { $0 > 0 }
        guard !leadTimes.isEmpty else { throw RepositoryError.invalidState("Keine gültigen Vorlaufzeiten für Kalender-Alarme.") }
        let calendarDuration: TimeInterval = 60 * 60 // 1 hour per discrete reminder time
        var firstError: Error?
        var failureCount = 0
        var didChangeLinks = false

        for trip in trips {
            do {
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

                let desiredByKey = buildDesiredDeadlineLinks(
                    eligibleDeadlines: eligibleDeadlines,
                    bookingsByID: bookingsByID,
                    bookingTitles: bookingTitles,
                    leadTimes: leadTimes,
                    trip: trip
                )
                let desiredKeys = Set(desiredByKey.keys)

                let existingLinks = try linkRepo.fetchLinks(forTripID: trip.id)
                let existingByKey = existingLinksByKey(existingLinks: existingLinks)

                // 1) Upsert desired EKEvents + EKReminders + links.
                try upsertDesiredDeadlineLinks(
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
                didChangeLinks = true

                // 2) Delete unwanted links and EK items.
                let unwantedLinks = unwantedLinks(existingLinks: existingLinks, desiredKeys: desiredKeys)
                if !unwantedLinks.isEmpty {
                    try deleteUnwantedDeadlineLinks(
                        links: unwantedLinks,
                        store: store,
                        linkRepo: linkRepo
                    )
                    didChangeLinks = true
                }
            } catch {
                if firstError == nil { firstError = error }
                failureCount += 1
            }
        }

        try finalizeCancellationDeadlineSync(
            linkRepo: linkRepo,
            didChangeLinks: didChangeLinks,
            failureCount: failureCount,
            firstError: firstError
        )
    }

    private func calendarTitle(
        for trip: Trip,
        kind: EKEntityType,
        calendarTitleMode: CalendarTitleMode,
        eventCalendarTitle: String,
        reminderCalendarTitle: String
    ) -> String {
        switch calendarTitleMode {
        case .fixed:
            return kind == .event ? eventCalendarTitle : reminderCalendarTitle
        case .tripTitle:
            return trip.title
        }
    }

    private func requestAccess(store: EKEventStore) async throws -> Bool {
        let eventsGranted = try await store.requestEventAccess()
        guard eventsGranted else { throw EventKitError.accessDenied }
        return try await store.requestReminderAccess()
    }

    private func requireCancellationDeadlineLinkRepository() throws -> CancellationDeadlineLinkRepository {
        guard let cancellationDeadlineLinkRepository else {
            throw RepositoryError.invalidState("CancellationDeadlineLinkRepository fehlt in LocalEventKitBridge.")
        }
        return cancellationDeadlineLinkRepository
    }

    private func finalizeCancellationDeadlineSync(
        linkRepo: CancellationDeadlineLinkRepository,
        didChangeLinks: Bool,
        failureCount: Int,
        firstError: Error?
    ) throws {
        if didChangeLinks {
            try linkRepo.save()
        }
        if failureCount > 0, let firstError {
            throw firstError
        }
    }

    private func reminderCalendarIfNeeded(
        shouldWriteReminders: Bool,
        trip: Trip,
        store: EKEventStore,
        reminderCalendarTitle: String,
        calendarTitleMode: CalendarTitleMode,
        reminderCreateIfMissing: Bool
    ) throws -> EKCalendar? {
        guard shouldWriteReminders else { return nil }
        return try ensureCalendar(
            named: calendarTitle(
                for: trip,
                kind: .reminder,
                calendarTitleMode: calendarTitleMode,
                eventCalendarTitle: "",
                reminderCalendarTitle: reminderCalendarTitle
            ),
            kind: .reminder,
            store: store,
            createIfMissing: reminderCreateIfMissing
        )
    }

    private func buildDesiredDeadlineLinks(
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

            let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
            let bookingTitle = bookingTitles[bookingID] ?? "Buchung"

            for leadDays in leadTimes {
                guard let fireAt = Calendar.current.date(byAdding: .day, value: -leadDays, to: deadline.deadlineAt) else { continue }
                guard fireAt > Date() else { continue }

                let key = DeadlineLinkKey(cancellationDeadlineID: deadline.id, leadDays: leadDays)
                desiredByKey[key] = DesiredDeadlineLinkInfo(
                    linkKey: key,
                    trip: trip,
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

    private func existingLinksByKey(
        existingLinks: [CancellationDeadlineLink]
    ) -> [DeadlineLinkKey: CancellationDeadlineLink] {
        var existingByKey: [DeadlineLinkKey: CancellationDeadlineLink] = [:]
        for link in existingLinks {
            existingByKey[DeadlineLinkKey(cancellationDeadlineID: link.cancellationDeadlineID, leadDays: link.leadDays)] = link
        }
        return existingByKey
    }

    private func upsertDesiredDeadlineLinks(
        desiredByKey: [DeadlineLinkKey: DesiredDeadlineLinkInfo],
        existingByKey: [DeadlineLinkKey: CancellationDeadlineLink],
        trip: Trip,
        store: EKEventStore,
        eventCalendar: EKCalendar,
        reminderCalendar: EKCalendar?,
        shouldWriteReminders: Bool,
        calendarDuration: TimeInterval,
        linkRepo: CancellationDeadlineLinkRepository
    ) throws {
        for (_, info) in desiredByKey {
            let existingLink = existingByKey[info.linkKey]
            let existingEvent = existingLink.flatMap { store.event(withIdentifier: $0.eventIdentifier) }

            let event: EKEvent = existingEvent ?? EKEvent(eventStore: store)
            event.title = "Stornofrist: \(info.bookingTitle)"
            event.calendar = eventCalendar
            event.timeZone = info.timeZone
            event.url = info.booking.externalUrl.flatMap { URL(string: $0) }
            event.startDate = info.fireAt
            event.endDate = info.fireAt.addingTimeInterval(calendarDuration)

            let deadlineText = Self.formatDeadlineWallClock(info.deadline)
            event.notes = """
            Reisen: Storno / Stornofrist
            Deadline: \(deadlineText)
            Vorlauf: \(info.linkKey.leadDays) Tage
            Booking: \(info.bookingTitle)
            """

            // Ensure resync doesn't accumulate alarms.
            event.alarms = []
            event.addAlarm(EKAlarm(absoluteDate: info.fireAt))
            try store.save(event, span: .thisEvent)

            let reminderIdentifier = try upsertReminderIfNeeded(
                existingLink: existingLink,
                reminderCalendar: reminderCalendar,
                shouldWriteReminders: shouldWriteReminders,
                store: store,
                info: info,
                deadlineText: deadlineText,
                timeZone: info.timeZone
            )

            let linkID = existingLink?.id ?? UUID()
            let updatedLink = CancellationDeadlineLink(
                id: linkID,
                ownerTripID: trip.id,
                ownerBookingID: info.booking.id,
                cancellationDeadlineID: info.deadline.id,
                leadDays: info.linkKey.leadDays,
                eventIdentifier: event.eventIdentifier,
                reminderIdentifier: reminderIdentifier,
                lastSyncedAt: Date()
            )
            try linkRepo.upsert(updatedLink)
        }
    }

    private func upsertReminderIfNeeded(
        existingLink: CancellationDeadlineLink?,
        reminderCalendar: EKCalendar?,
        shouldWriteReminders: Bool,
        store: EKEventStore,
        info: DesiredDeadlineLinkInfo,
        deadlineText: String,
        timeZone: TimeZone
    ) throws -> String? {
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

        // Reset alarms so resync doesn't accumulate duplicates.
        reminder.alarms = []
        reminder.addAlarm(EKAlarm(absoluteDate: info.fireAt))

        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    private func unwantedLinks(
        existingLinks: [CancellationDeadlineLink],
        desiredKeys: Set<DeadlineLinkKey>
    ) -> [CancellationDeadlineLink] {
        existingLinks.filter { link in
            let key = DeadlineLinkKey(cancellationDeadlineID: link.cancellationDeadlineID, leadDays: link.leadDays)
            return !desiredKeys.contains(key)
        }
    }

    private func deleteUnwantedDeadlineLinks(
        links: [CancellationDeadlineLink],
        store: EKEventStore,
        linkRepo: CancellationDeadlineLinkRepository
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

    func syncTripTimelineEntries(
        trips: [Trip],
        bookings: [Booking],
        bookingTitles: [UUID: String],
        eventCalendarTitle: String,
        eventCreateIfMissing: Bool,
        includeTripStartEnd: Bool,
        includeFlightTimes: Bool,
        includeHotelStays: Bool
    ) async throws {
        guard let calendarEventLinkRepository else {
            throw RepositoryError.invalidState("CalendarEventLinkRepository fehlt in LocalEventKitBridge.")
        }

        if trips.isEmpty { return }

        let store = EKEventStore()
        let eventsGranted = try await store.requestEventAccess()
        if !eventsGranted { throw EventKitError.accessDenied }

        let eventCalendar = try ensureCalendar(
            named: eventCalendarTitle,
            kind: .event,
            store: store,
            createIfMissing: eventCreateIfMissing
        )

        let bookingsByID = Dictionary(uniqueKeysWithValues: bookings.map { ($0.id, $0) })
        let calendarDuration: TimeInterval = 60 * 60 // 1 hour for discrete (non-all-day) entries

        let composer = CalendarTimelineComposer()
        let drafts = composer.compose(
            trips: trips,
            bookings: bookings,
            bookingTitles: bookingTitles,
            includeTripStartEnd: includeTripStartEnd,
            includeFlightTimes: includeFlightTimes,
            includeHotelStays: includeHotelStays
        )

        let draftsByTripID = Dictionary(grouping: drafts, by: { $0.ownerTripID })

        var firstError: Error?
        var failureCount = 0
        var didChangeLinks = false

        for trip in trips {
            do {
                let tripDrafts = draftsByTripID[trip.id] ?? []
                let desiredKeys = Set(tripDrafts.map(eventLinkKey(for:)))

                let existingLinks = try calendarEventLinkRepository.fetchLinks(forTripID: trip.id)
                let existingByKey = Dictionary(uniqueKeysWithValues: existingLinks.map { (eventLinkKey(for: $0), $0) })

                // 1) Upsert desired events + links.
                for draft in tripDrafts {
                    try upsertEventAndLink(
                        store: store,
                        eventCalendar: eventCalendar,
                        draft: draft,
                        bookingsByID: bookingsByID,
                        existingLink: existingByKey[eventLinkKey(for: draft)],
                        calendarDuration: calendarDuration,
                        calendarEventLinkRepository: calendarEventLinkRepository
                    )
                    didChangeLinks = true
                }

                // 2) Delete events/links that are no longer desired.
                let unwantedLinks = existingLinks.filter { !desiredKeys.contains(eventLinkKey(for: $0)) }
                let unwantedIDs = unwantedLinks.map(\.id)
                if !unwantedIDs.isEmpty {
                    try removeUnwantedEvents(store: store, links: unwantedLinks)
                    try calendarEventLinkRepository.deleteLinks(ids: unwantedIDs)
                    didChangeLinks = true
                }
            } catch {
                if firstError == nil { firstError = error }
                failureCount += 1
            }
        }

        if didChangeLinks {
            try calendarEventLinkRepository.save()
        }

        if failureCount > 0, let firstError { throw firstError }
    }

    private func eventLinkKey(for draft: CalendarEventDraft) -> EventLinkKey {
        EventLinkKey(role: draft.role, ownerBookingID: draft.ownerBookingID)
    }

    private func eventLinkKey(for link: CalendarEventLink) -> EventLinkKey {
        EventLinkKey(role: link.role, ownerBookingID: link.ownerBookingID)
    }

    private func timeZone(for draft: CalendarEventDraft, bookingsByID: [UUID: Booking]) -> TimeZone {
        switch draft.role {
        case .tripStart, .tripEnd:
            if let offset = draft.timeZoneOffsetSecondsFromGMT {
                return TimeZone(secondsFromGMT: offset) ?? .current
            }
            return .current
        case .hotelStay:
            guard let bookingID = draft.ownerBookingID, let booking = bookingsByID[bookingID] else { return .current }
            return booking.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        case .flightDeparture:
            guard let bookingID = draft.ownerBookingID, let booking = bookingsByID[bookingID] else { return .current }
            return booking.flightDepartureOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        case .flightArrival:
            guard let bookingID = draft.ownerBookingID, let booking = bookingsByID[bookingID] else { return .current }
            return booking.flightArrivalOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        }
    }

    private func upsertEventAndLink(
        store: EKEventStore,
        eventCalendar: EKCalendar,
        draft: CalendarEventDraft,
        bookingsByID: [UUID: Booking],
        existingLink: CalendarEventLink?,
        calendarDuration: TimeInterval,
        calendarEventLinkRepository: CalendarEventLinkRepository
    ) throws {
        let tz = timeZone(for: draft, bookingsByID: bookingsByID)

        let event: EKEvent
        if let existingLink,
           let existingEvent = store.event(withIdentifier: existingLink.eventIdentifier) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: store)
        }

        event.title = draft.title
        event.calendar = eventCalendar
        event.url = draft.url
        event.notes = draft.notes

        configureEventDates(
            event: event,
            draft: draft,
            tz: tz,
            calendarDuration: calendarDuration
        )

        if let location = draft.locationAddress {
            event.location = location
        }

        try store.save(event, span: .thisEvent)

        #if DEBUG
        debugLogHotelStaySaved(store: store, draft: draft, event: event)
        #endif

        let linkID = existingLink?.id ?? UUID()
        let updatedLink = CalendarEventLink(
            id: linkID,
            role: draft.role,
            ownerTripID: draft.ownerTripID,
            ownerBookingID: draft.ownerBookingID,
            eventIdentifier: event.eventIdentifier,
            calendarItemExternalIdentifier: nil,
            lastSyncedAt: Date()
        )
        try calendarEventLinkRepository.upsert(updatedLink)
    }

    private func configureEventDates(
        event: EKEvent,
        draft: CalendarEventDraft,
        tz: TimeZone,
        calendarDuration: TimeInterval
    ) {
        if draft.isAllDay {
            // Apple Best Practice: isAllDay VOR start/end setzen.
            // macOS EventKit: endDate bei All-day = letzter INKLUSIVER Tag (nicht +1/exklusiv).
            event.isAllDay = true
            event.timeZone = nil

            let span: CalendarAllDaySpan.Range
            if draft.role == .hotelStay {
                // Exakt die Buchungs-Tagesdaten (Start-Tag … End-Tag), ohne Uhrzeit/TZ.
                span = CalendarAllDaySpan.hotelStayRange(
                    startDateOnly: draft.startDate,
                    endDateOnlyInclusive: draft.endDate
                )
            } else {
                span = CalendarAllDaySpan.eventKitRange(
                    startInstant: draft.startDate,
                    endInstantInclusive: draft.endDate,
                    civilTimeZone: tz
                )
            }

            event.startDate = span.start
            event.endDate = span.end

            #if DEBUG
            if draft.role == .hotelStay {
                let s = span.startDay
                let e = span.endDayInclusive
                SyncLog.append(
                    "calendar.hotelStay title=\(draft.title) bookingDays=\(s.day ?? 0).\(s.month ?? 0).\(s.year ?? 0)–\(e.day ?? 0).\(e.month ?? 0).\(e.year ?? 0)"
                )
            }
            #endif
        } else {
            event.isAllDay = false
            // Für zeitbasierte Events brauchen wir die richtige TZ.
            event.timeZone = tz
            event.startDate = draft.startDate
            event.endDate = draft.endDate.addingTimeInterval(calendarDuration)
        }
    }

    #if DEBUG
    private func debugLogHotelStaySaved(store: EKEventStore, draft: CalendarEventDraft, event: EKEvent) {
        if draft.role == .hotelStay,
           let saved = store.event(withIdentifier: event.eventIdentifier) {
            let cal = Calendar.current
            SyncLog.append(
                "calendar.hotelStay.saved title=\(saved.title ?? "") startDay=\(cal.component(.day, from: saved.startDate)).\(cal.component(.month, from: saved.startDate)) endDay=\(cal.component(.day, from: saved.endDate)).\(cal.component(.month, from: saved.endDate)) isAllDay=\(saved.isAllDay)"
            )
        }
    }
    #endif

    private func removeUnwantedEvents(store: EKEventStore, links: [CalendarEventLink]) throws {
        for link in links {
            if let event = store.event(withIdentifier: link.eventIdentifier) {
                try store.remove(event, span: .thisEvent)
            }
        }
    }

    private func ensureCalendar(
        named title: String,
        kind: EKEntityType,
        store: EKEventStore,
        createIfMissing: Bool
    ) throws -> EKCalendar {
        // 1) Exact title match first
        if let existing = store.calendars(for: kind).first(where: { $0.title == title }) {
            return existing
        }

        // createIfMissing muss respektiert werden:
        // - Wenn aus Nutzer-Sicht kein Erstellen erlaubt ist, soll Sync mit einer klaren Fehlermeldung scheitern,
        //   statt ungefragt Kalender anzulegen.
        // - Wenn Erstellen erlaubt ist, legen wir den Kalender an.
        if !createIfMissing {
            if kind == .event {
                throw EventKitError.calendarNotFound
            } else {
                throw EventKitError.reminderCalendarNotFound
            }
        }

        return try createCalendar(named: title, kind: kind, store: store)
    }

    private func createCalendar(named title: String, kind: EKEntityType, store: EKEventStore) throws -> EKCalendar {
        let calendar = EKCalendar(for: kind, eventStore: store)
        calendar.title = title

        // Use a best-effort source: if the default source exists, reuse it.
        if kind == .event, let source = store.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if kind == .reminder, let def = store.defaultCalendarForNewReminders(), let source = def.source {
            calendar.source = source
        } else {
            calendar.source = store.sources.first
        }

        do {
            try store.saveCalendar(calendar, commit: true)
        } catch {
            let systemMessage = error.localizedDescription
            if systemMessage.localizedCaseInsensitiveContains("keine kalender hinzugefügt oder entfernt werden") ||
                systemMessage.localizedCaseInsensitiveContains("dürfen keine kalender hinzugefügt oder entfernt werden") {
                throw EventKitError.calendarModificationDenied
            }
            if kind == .event { throw EventKitError.calendarWriteFailed }
            throw EventKitError.reminderWriteFailed
        }

        return calendar
    }

    private func upsertEvent(
        store: EKEventStore,
        calendar: EKCalendar,
        title: String,
        startDate: Date,
        endDate: Date,
        timeZone: TimeZone
    ) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.timeZone = timeZone

        // Small window to avoid accidental duplicates when times are close due to TZ conversions.
        let startWindow = startDate.addingTimeInterval(-10 * 60)
        let endWindow = startDate.addingTimeInterval(10 * 60)
        let predicate = store.predicateForEvents(withStart: startWindow, end: endWindow, calendars: [calendar])
        let existingEvents = store.events(matching: predicate)

        if existingEvents.contains(where: {
            $0.title == title && abs($0.startDate.timeIntervalSince(startDate)) < 5
        }) {
            return
        }

        try store.save(event, span: .thisEvent)
    }
}

private extension LocalEventKitBridge {
    static func formatDeadlineWallClock(_ deadline: CancellationDeadline) -> String {
        let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = tz
        formatter.dateFormat = "d. MMM yyyy HH:mm"
        return formatter.string(from: deadline.deadlineAt)
    }
}

private extension EKEventStore {
    func requestEventAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.requestFullAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func requestReminderAccess() async throws -> Bool {
        // Reminders live in EventKit as EKReminders.
        try await withCheckedThrowingContinuation { continuation in
            self.requestFullAccessToReminders { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
