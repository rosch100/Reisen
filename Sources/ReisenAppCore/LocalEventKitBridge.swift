import Foundation
@preconcurrency import EventKit

import ReisenDomain
import ReisenDiagnostics
import SwiftData
import ReisenData

@MainActor
public final class LocalEventKitBridge: CalendarSyncing {
    private let calendarEventLinkRepository: CalendarEventLinkRepository?
    private let cancellationDeadlineLinkRepository: CancellationDeadlineLinkRepository?
    var preTravelHintLinkRepository: PreTravelHintLinkRepository?

    public init() {
        self.calendarEventLinkRepository = nil
        self.cancellationDeadlineLinkRepository = nil
        self.preTravelHintLinkRepository = nil
    }

    public init(modelContext: ModelContext) {
        self.calendarEventLinkRepository = SwiftDataCalendarEventLinkRepository(modelContext: modelContext)
        self.cancellationDeadlineLinkRepository = SwiftDataCancellationDeadlineLinkRepository(modelContext: modelContext)
        self.preTravelHintLinkRepository = SwiftDataPreTravelHintLinkRepository(modelContext: modelContext)
    }

    private struct EventLinkKey: Hashable {
        let role: CalendarEventRole
        let ownerBookingID: UUID?
    }

    public func fetchEventCalendarTitles() async throws -> [String] {
        let store = EKEventStore()
        let granted = try await store.requestEventAccess()
        guard granted else { throw EventKitError.accessDenied }

        return store.calendars(for: .event).map(\.title).sorted()
    }

    public func fetchReminderCalendarTitles() async throws -> [String] {
        let store = EKEventStore()
        let granted = try await store.requestReminderAccess()
        guard granted else { throw EventKitError.reminderAccessDenied }

        return store.calendars(for: .reminder).map(\.title).sorted()
    }

    public func syncCancellationDeadlines(
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
        let linkRepo = try requireCancellationDeadlineLinkRepository()
        if trips.isEmpty || deadlines.isEmpty { return }

        let runID = UUID()
        await recordCancellationDeadlineSync(
            runID: runID,
            event: "sync_started",
            result: .started
        )

        var didRecordFinished = false
        do {
            var existingLinksByTripID: [UUID: [CancellationDeadlineLink]] = [:]
            for trip in trips {
                existingLinksByTripID[trip.id] = try linkRepo.fetchLinks(forTripID: trip.id)
            }

            let request = EventKitDeadlineWriterRequest(
                trips: trips,
                bookings: bookings,
                deadlines: deadlines,
                bookingTitles: bookingTitles,
                eventCalendarTitle: eventCalendarTitle,
                reminderCalendarTitle: reminderCalendarTitle,
                eventCreateIfMissing: eventCreateIfMissing,
                reminderCreateIfMissing: reminderCreateIfMissing,
                calendarTitleMode: calendarTitleMode,
                leadTimesDays: leadTimesDays,
                existingLinksByTripID: existingLinksByTripID
            )

            do {
                let plan = try await EventKitDeadlineWriter().syncDeadlines(request)
                try CancellationDeadlineLinkPersister.apply(plan, linkRepo: linkRepo)
                await recordCancellationDeadlineSync(
                    runID: runID,
                    event: "sync_finished",
                    result: .succeeded,
                    durationMilliseconds: plan.durationMilliseconds,
                    reason: "events=\(plan.eventSaveCount);reminders=\(plan.reminderSaveCount)"
                )
                didRecordFinished = true
            } catch let partial as EventKitDeadlinePartialSyncError {
                do {
                    try CancellationDeadlineLinkPersister.apply(partial.plan, linkRepo: linkRepo)
                } catch {
                    await recordCancellationDeadlineSync(
                        runID: runID,
                        event: "sync_finished",
                        result: .failed,
                        durationMilliseconds: partial.plan.durationMilliseconds,
                        errorType: String(describing: type(of: error)),
                        reason: "eventkit_deadline_sync_partial_persist_failed"
                    )
                    didRecordFinished = true
                    throw error
                }
                await recordCancellationDeadlineSync(
                    runID: runID,
                    event: "sync_finished",
                    result: .failed,
                    durationMilliseconds: partial.plan.durationMilliseconds,
                    errorType: String(describing: type(of: partial.cause)),
                    reason: "eventkit_deadline_sync_partial_failed"
                )
                didRecordFinished = true
                throw partial.cause
            }
        } catch {
            if !didRecordFinished {
                await recordCancellationDeadlineSync(
                    runID: runID,
                    event: "sync_finished",
                    result: .failed,
                    errorType: String(describing: type(of: error)),
                    reason: "eventkit_deadline_sync_failed"
                )
            }
            throw error
        }
    }

    private func recordCancellationDeadlineSync(
        runID: UUID,
        event: String,
        result: DiagnosticResult,
        durationMilliseconds: Int? = nil,
        errorType: String? = nil,
        reason: String? = nil
    ) async {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: DiagnosticContext(runID: runID, providerID: .manual, operation: "eventkit_side_effect"),
                component: "LocalEventKitBridge",
                phase: "cancellation_deadlines",
                event: event,
                result: result,
                durationMilliseconds: durationMilliseconds,
                errorType: errorType,
                reason: reason,
                visibility: .publicDiagnostic
            )
        )
    }

    func calendarTitle(
        for trip: Trip,
        kind: EKEntityType,
        calendarTitleMode: CalendarTitleMode,
        eventCalendarTitle: String,
        reminderCalendarTitle: String
    ) -> String {
        EventKitCalendarSupport.title(
            for: trip,
            kind: kind,
            calendarTitleMode: calendarTitleMode,
            eventCalendarTitle: eventCalendarTitle,
            reminderCalendarTitle: reminderCalendarTitle
        )
    }

    func requestAccess(store: EKEventStore) async throws -> Bool {
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

    func reminderCalendarIfNeeded(
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

    public func syncTripTimelineEntries(
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
                let existingLinks = try calendarEventLinkRepository.fetchLinks(forTripID: trip.id)
                let existingByKey = Dictionary(uniqueKeysWithValues: existingLinks.map { (eventLinkKey(for: $0), $0) })

                // 1) Upsert only drafts with a resolvable offset. Missing offset must not stay in
                // desiredKeys — otherwise stale EventKit events/links would never be cleaned up.
                let eligible = Self.calendarDraftsEligibleForSync(
                    drafts: tripDrafts,
                    bookingsByID: bookingsByID
                )
                let desiredKeys = Set(eligible.map { eventLinkKey(for: $0.draft) })
                for draft in tripDrafts where !desiredKeys.contains(eventLinkKey(for: draft)) {
                    EventKitOffsetSkip.record(
                        component: "LocalEventKitBridge",
                        reason: "calendar_event_missing_offset_\(draft.role.rawValue)"
                    )
                }
                for item in eligible {
                    let key = eventLinkKey(for: item.draft)
                    try upsertEventAndLink(
                        store: store,
                        eventCalendar: eventCalendar,
                        draft: item.draft,
                        timeZone: item.timeZone,
                        existingLink: existingByKey[key],
                        calendarDuration: calendarDuration,
                        calendarEventLinkRepository: calendarEventLinkRepository
                    )
                    didChangeLinks = true
                }

                // 2) Delete events/links that are no longer desired (incl. offset-less skips).
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

    private static func timeZone(for draft: CalendarEventDraft, bookingsByID: [UUID: Booking]) -> TimeZone? {
        switch draft.role {
        case .tripStart, .tripEnd:
            guard let offset = draft.timeZoneOffsetSecondsFromGMT else { return nil }
            return TimeZone(secondsFromGMT: offset)
        case .hotelStay:
            guard let bookingID = draft.ownerBookingID, let booking = bookingsByID[bookingID] else { return nil }
            return booking.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
        case .flightDeparture:
            guard let bookingID = draft.ownerBookingID, let booking = bookingsByID[bookingID] else { return nil }
            return booking.flightDepartureOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
        case .flightArrival:
            guard let bookingID = draft.ownerBookingID, let booking = bookingsByID[bookingID] else { return nil }
            return booking.flightArrivalOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
        }
    }

    /// Drafts that enter EventKit `desiredKeys` (have a resolvable offset). Offset-less drafts are omitted so stale links cleanup.
    static func calendarDraftsEligibleForSync(
        drafts: [CalendarEventDraft],
        bookingsByID: [UUID: Booking]
    ) -> [(draft: CalendarEventDraft, timeZone: TimeZone)] {
        drafts.compactMap { draft in
            guard let tz = timeZone(for: draft, bookingsByID: bookingsByID) else { return nil }
            return (draft, tz)
        }
    }

    private func upsertEventAndLink(
        store: EKEventStore,
        eventCalendar: EKCalendar,
        draft: CalendarEventDraft,
        timeZone tz: TimeZone,
        existingLink: CalendarEventLink?,
        calendarDuration: TimeInterval,
        calendarEventLinkRepository: CalendarEventLinkRepository
    ) throws {
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

    /// All-day EventKit-Spanne: Trip-/Hotel-Grenzen über `HotelStayDate` Y/M/D-SSOT;
    /// Flight-All-day (falls) über Civil-TZ des Drafts.
    static func allDaySpan(
        for draft: CalendarEventDraft,
        civilTimeZone: TimeZone
    ) -> CalendarAllDaySpan.Range {
        switch draft.role {
        case .hotelStay, .tripStart, .tripEnd:
            return CalendarAllDaySpan.hotelStayRange(
                startDateOnly: draft.startDate,
                endDateOnlyInclusive: draft.endDate
            )
        case .flightDeparture, .flightArrival:
            return CalendarAllDaySpan.eventKitRange(
                startInstant: draft.startDate,
                endInstantInclusive: draft.endDate,
                civilTimeZone: civilTimeZone
            )
        }
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

            // Trip-/Hotel-All-day: Y/M/D aus HotelStayDate-SSOT (nicht Hotel-Civil-TZ).
            // `tz` bleibt für Eligibility/Notes; EventKit All-day setzt timeZone = nil.
            let span = Self.allDaySpan(for: draft, civilTimeZone: tz)

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

    func ensureCalendar(
        named title: String,
        kind: EKEntityType,
        store: EKEventStore,
        createIfMissing: Bool
    ) throws -> EKCalendar {
        try EventKitCalendarSupport.ensureCalendar(
            named: title,
            kind: kind,
            store: store,
            createIfMissing: createIfMissing,
            saveCalendarCommit: true
        ).calendar
    }
}

extension EKEventStore {
    func requestEventAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.requestFullAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func requestReminderAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.requestFullAccessToReminders { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}

