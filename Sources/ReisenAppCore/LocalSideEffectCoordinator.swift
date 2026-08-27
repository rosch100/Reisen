import Foundation
import SwiftData
import CoreData

import ReisenDomain
import ReisenData

@MainActor
package final class LocalSideEffectCoordinator {
    private let modelContext: ModelContext
    private let reminderScheduler: LocalReminderScheduler
    private let calendarSync: LocalEventKitBridge
    private var cloudSideEffectTask: Task<Void, Never>?
    private var isRebuildingSideEffects = false

    package init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.reminderScheduler = LocalReminderScheduler(modelContext: modelContext)
        self.calendarSync = LocalEventKitBridge(modelContext: modelContext)
    }

    package func rebuildLocalSideEffects(
        isSyncing: Bool,
        settings: AppSettings,
        announceProgress: Bool,
        setStatusMessage: (String) -> Void,
        handleError: (Error, Bool) -> Void,
        clearMessageProvider: () -> Void
    ) async {
        guard !isSyncing else { return }
        guard !isRebuildingSideEffects else { return }
        isRebuildingSideEffects = true
        defer { isRebuildingSideEffects = false }

        do {
            let skipped = try await scheduleAndSyncFromStore(
                settings: settings,
                announceProgress: announceProgress,
                setStatusMessage: setStatusMessage
            )
            if announceProgress, let hint = PrivacyOptionalCapability.statusHint(skipped: skipped) {
                setStatusMessage(hint)
            }
        } catch {
            if let pane = PrivacyOptionalCapability.deniedPane(from: error) {
                if announceProgress,
                   let hint = PrivacyOptionalCapability.statusHint(skipped: [pane]) {
                    setStatusMessage(hint)
                }
                clearMessageProvider()
                return
            }
            handleError(error, !announceProgress)
            clearMessageProvider()
        }
    }

    package func startObservingCloudSideEffects(
        isSyncing: @escaping () -> Bool,
        onRemoteChange: @escaping () async -> Void
    ) {
        stopObservingCloudSideEffects()
        cloudSideEffectTask = Task { @MainActor [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .NSPersistentStoreRemoteChange
            )
            for await _ in notifications {
                guard self != nil else { return }
                guard !isSyncing() else { continue }
                try? await Task.sleep(for: .milliseconds(750))
                await onRemoteChange()
            }
        }
    }

    package func stopObservingCloudSideEffects() {
        cloudSideEffectTask?.cancel()
        cloudSideEffectTask = nil
    }

    package func scheduleAndSyncFromStore(
        settings: AppSettings,
        announceProgress: Bool,
        setStatusMessage: (String) -> Void
    ) async throws -> [PrivacySettingPane] {
        let bookingRepo = SwiftDataBookingRepository(modelContext: modelContext)
        let deadlineRepo = SwiftDataCancellationDeadlineRepository(modelContext: modelContext)
        let bookings = try bookingRepo.fetchAll()
        let deadlines = try deadlineRepo.fetchAll()
        return try await maybeScheduleAndSyncCalendars(
            settings: settings,
            bookings: bookings,
            deadlines: deadlines,
            bookingTitles: bookings.titleByID,
            bookingRepo: bookingRepo,
            announceProgress: announceProgress,
            setStatusMessage: setStatusMessage
        )
    }

    package func maybeScheduleAndSyncCalendars(
        settings: AppSettings,
        bookings: [Booking],
        deadlines: [CancellationDeadline],
        bookingTitles: [UUID: String],
        bookingRepo: SwiftDataBookingRepository,
        announceProgress: Bool,
        setStatusMessage: (String) -> Void
    ) async throws -> [PrivacySettingPane] {
        var skipped: [PrivacySettingPane] = []

        if settings.notificationEnabled {
            if announceProgress { setStatusMessage("Plane Erinnerungen…") }
            if let pane = try await PrivacyOptionalCapability.run({
                _ = try await reminderScheduler.scheduleCancellationDeadlines(
                    deadlines: deadlines,
                    bookingTitles: bookingTitles,
                    leadTimesDays: settings.leadTimesDays
                )
                _ = try await reminderScheduler.schedulePreTravelHints(
                    bookings: bookings,
                    bookingTitles: bookingTitles,
                    leadTimesDays: settings.leadTimesDays
                )
            }) {
                skipped.append(pane)
            }
        }

        if settings.eventKitEnabled {
            if announceProgress { setStatusMessage("Schreibe Kalender…") }

            let tripRepo = SwiftDataTripRepository(modelContext: modelContext)
            let trips = try tripRepo.fetchAll()

            let effectiveEventCreateIfMissing = settings.eventCalendarCreateIfMissing
            let effectiveReminderCreateIfMissing = settings.reminderCalendarCreateIfMissing

            if let pane = try await PrivacyOptionalCapability.run({
                try await calendarSync.syncCancellationDeadlines(
                    trips: trips,
                    bookings: bookings,
                    deadlines: deadlines,
                    bookingTitles: bookingTitles,
                    eventCalendarTitle: settings.calendarTitle,
                    reminderCalendarTitle: settings.reminderCalendarTitle,
                    eventCreateIfMissing: effectiveEventCreateIfMissing,
                    reminderCreateIfMissing: effectiveReminderCreateIfMissing,
                    calendarTitleMode: settings.calendarTitleMode,
                    leadTimesDays: settings.leadTimesDays
                )
                try await calendarSync.syncPreTravelHints(
                    trips: trips,
                    bookings: bookings,
                    bookingTitles: bookingTitles,
                    eventCalendarTitle: settings.calendarTitle,
                    reminderCalendarTitle: settings.reminderCalendarTitle,
                    eventCreateIfMissing: effectiveEventCreateIfMissing,
                    reminderCreateIfMissing: effectiveReminderCreateIfMissing,
                    calendarTitleMode: settings.calendarTitleMode,
                    leadTimesDays: settings.leadTimesDays
                )
            }) {
                skipped.append(pane)
            }

            let calendarDenied = skipped.contains(.calendars)
            if !calendarDenied, settings.calendarTimelineEnabled {
                if announceProgress { setStatusMessage("Schreibe Reisezeiten…") }

                var bookingsMutable = bookings

                if settings.needsHotelAddressesForCalendar || settings.calendarFlightTimesEnabled {
                    if announceProgress { setStatusMessage("Löse Adressen auf…") }
                    try await resolveAndPersistBookingAddressesIfNeeded(
                        needsHotelAddresses: settings.needsHotelAddressesForCalendar,
                        needsFlightAddresses: settings.calendarFlightTimesEnabled,
                        bookings: &bookingsMutable,
                        bookingRepo: bookingRepo
                    )
                }

                if let pane = try await PrivacyOptionalCapability.run({
                    try await calendarSync.syncTripTimelineEntries(
                        trips: trips,
                        bookings: bookingsMutable,
                        bookingTitles: bookingTitles,
                        eventCalendarTitle: settings.calendarTitle,
                        eventCreateIfMissing: settings.eventCalendarCreateIfMissing,
                        includeTripStartEnd: settings.calendarTripTimesEnabled,
                        includeFlightTimes: settings.calendarFlightTimesEnabled,
                        includeHotelStays: settings.calendarHotelStaysEnabled
                    )
                }) {
                    skipped.append(pane)
                }
            }
        }

        return skipped
    }

    private func resolveAndPersistBookingAddressesIfNeeded(
        needsHotelAddresses: Bool,
        needsFlightAddresses: Bool,
        bookings: inout [Booking],
        bookingRepo: SwiftDataBookingRepository
    ) async throws {
        let resolver = MapKitAddressResolver()
        var addressCache: [String: String?] = [:]
        var changedBookingIDs = Set<UUID>()

        func resolveCached(_ query: String) async {
            if addressCache.keys.contains(query) { return }
            do {
                addressCache[query] = try await resolver.resolveAddress(query: query)
            } catch {
                addressCache[query] = nil
            }
        }

        func hotelFallbackQuery(
            booking: Booking,
            locationPart: String?
        ) -> String? {
            let title = booking.title?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let location = locationPart?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            switch (title, location) {
            case let (t?, l?) where !t.isEmpty && !l.isEmpty:
                return "\(t), \(l)"
            case let (t?, nil) where !t.isEmpty:
                return t
            case let (nil, l?) where !l.isEmpty:
                return l
            default:
                return nil
            }
        }

        for idx in bookings.indices {
            let booking = bookings[idx]

            let shouldResolveHotel = needsHotelAddresses && booking.bookingType == .hotel
            let shouldResolveFlight = needsFlightAddresses && booking.bookingType == .flight
            guard shouldResolveHotel || shouldResolveFlight else { continue }

            var updated = booking
            var didChange = false

            if updated.locationFromAddress == nil,
               let fromQuery = (shouldResolveHotel
                                ? hotelFallbackQuery(booking: updated, locationPart: updated.locationFrom)
                                : updated.locationFrom),
               !fromQuery.isEmpty {
                await resolveCached(fromQuery)
                if let resolved = addressCache[fromQuery] ?? nil {
                    updated.locationFromAddress = resolved
                    didChange = true
                }
            }

            if updated.locationToAddress == nil,
               let toQuery = (shouldResolveHotel
                              ? hotelFallbackQuery(booking: updated, locationPart: updated.locationTo)
                              : updated.locationTo),
               !toQuery.isEmpty {
                await resolveCached(toQuery)
                if let resolved = addressCache[toQuery] ?? nil {
                    updated.locationToAddress = resolved
                    didChange = true
                }
            }

            if didChange {
                bookings[idx] = updated
                changedBookingIDs.insert(updated.id)
            }
        }

        guard !changedBookingIDs.isEmpty else { return }

        for booking in bookings where changedBookingIDs.contains(booking.id) {
            try bookingRepo.upsert(booking)
        }
        try bookingRepo.save()
    }
}
