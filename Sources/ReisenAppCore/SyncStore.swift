import Foundation
import Observation
import SwiftData

import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenCheck24
import ReisenOpodo
import ReisenBookingCom
import ReisenAirbnb
import WebKit

@MainActor
@Observable
public final class SyncStore {
    public var isSyncing = false
    public var syncingProviderID: ProviderID?
    /// Welcher Provider die aktuelle Status-/Fehlermeldung erzeugt hat.
    public var messageProviderID: ProviderID?
    public var errorMessage: String?
    public var statusMessage: String?

    private let modelContext: ModelContext
    private let registry: ProviderRegistry
    private let reminderScheduler: LocalReminderScheduler
    private let calendarSync: LocalEventKitBridge

    public init(modelContext: ModelContext, registry: ProviderRegistry) {
        self.modelContext = modelContext
        self.registry = registry
        self.reminderScheduler = LocalReminderScheduler(modelContext: modelContext)
        self.calendarSync = LocalEventKitBridge(modelContext: modelContext)
    }

    public func sync(
        providerID: ProviderID,
        webView: WKWebView,
        settings: AppSettings
    ) async {
        if !providerIsEnabled(providerID) {
            errorMessage = "Provider \(providerID.rawValue) ist deaktiviert."
            statusMessage = nil
            messageProviderID = providerID
            return
        }

        syncingProviderID = providerID
        messageProviderID = providerID
        isSyncing = true
        errorMessage = nil
        statusMessage = "Synchronisiere…"
        defer {
            isSyncing = false
            syncingProviderID = nil
        }

        // We may need provider enrichment (incl. offsets) even if the user only wants calendar
        // entries for trip/flight times (timezone correctness).
        let requiresDeadlines = settings.notificationEnabled
            || settings.eventKitEnabled
            || settings.calendarTripTimesEnabled
            || settings.calendarFlightTimesEnabled
        let attemptStart = Date()

        do {
            guard let anyProvider = registry.provider(id: providerID) else {
                throw RepositoryError.invalidState("Provider \(providerID.rawValue) ist nicht verfügbar.")
            }

            attachProviderProgressCallback(providerID: providerID, provider: anyProvider)

            let session: any ProviderSession = {
                if providerID == .check24 {
                    return Check24WebSession(webView: webView)
                }
                return WebViewProviderSession(webView: webView)
            }()

            let catalog = try await anyProvider.fetchCatalog(session: session)

            // Ensure required enrichment fields (e.g. cancellation deadlines) are present.
            // Some providers may return list-level data only; provider-specific `enrichBooking`
            // is used as the second step.
            var drafts = catalog.bookings
            try await enrichDraftsIfNeeded(
                providerID: providerID,
                provider: anyProvider,
                session: session,
                requiresDeadlines: requiresDeadlines,
                drafts: &drafts
            )

            // Stornierte Katalog-Einträge weglassen → deleteProviderBookings entfernt sie lokal.
            let cancelledCount = drafts.filter { $0.status == .cancelled }.count
            let activeDrafts = drafts.filter { $0.status != .cancelled }
            // Flüge haben oft keine Stornofristen — Hinweis nur, wenn Hotels/Andere ohne Fristen bleiben.
            let deadlineEligible = activeDrafts.filter { $0.bookingType == .hotel || $0.bookingType == .other }
            let missingDeadlinesHint = requiresDeadlines
                && !deadlineEligible.isEmpty
                && deadlineEligible.allSatisfy(\.deadlines.isEmpty)
            if providerID == .booking {
                let hotels = activeDrafts.filter { $0.bookingType == .hotel }
                let withDeadlines = activeDrafts.filter { !$0.deadlines.isEmpty }.count
                let hotelURLSample = hotels.first?.externalUrl.map { String($0.prefix(120)) } ?? "-"
                SyncLog.append(
                    "enrich_deadlines provider=booking active=\(activeDrafts.count) hotels=\(hotels.count) withDeadlines=\(withDeadlines) hotelUrl=\(hotelURLSample)"
                )
            }

            let bookingRepo = SwiftDataBookingRepository(modelContext: modelContext)
            let tripRepo = SwiftDataTripRepository(modelContext: modelContext)
            let useCase = SyncProviderBookings(
                bookingRepository: bookingRepo
            )
            statusMessage = "Speichere Daten…"
            let stats = try useCase.execute(
                provider: providerID,
                drafts: activeDrafts,
                requiresDeadlines: false
            )

            try await FlightTimeZoneAssigner(bookingRepository: bookingRepo).assignMissingOffsets()
            try TimeNormalizationRepair(bookingRepository: bookingRepo).repairIfNeeded()

            try assignTripsAfterNormalization(bookingRepo: bookingRepo, tripRepo: tripRepo)

            let deadlineRepo = SwiftDataCancellationDeadlineRepository(modelContext: modelContext)
            let deadlines = try deadlineRepo.fetchAll()
            var bookings = try bookingRepo.fetchAll()
            let titles = Dictionary(uniqueKeysWithValues: bookings.map { ($0.id, $0.title ?? $0.bookingType.rawValue.capitalized) })

            try await maybeScheduleAndSyncCalendars(
                settings: settings,
                bookings: bookings,
                deadlines: deadlines,
                bookingTitles: titles,
                bookingRepo: bookingRepo
            )

            if missingDeadlinesHint {
                statusMessage =
                    "Synchronisiert (\(stats.bookingsPersisted) Buchungen). Hinweis: Keine Stornofristen gefunden."
            } else {
                statusMessage =
                    "Synchronisation abgeschlossen. (\(stats.bookingsPersisted) Buchungen, \(stats.deadlinesPersisted) Stornofristen)"
            }
            messageProviderID = providerID
            SyncLog.append(
                "result=success provider=\(providerID.rawValue) bookings=\(stats.bookingsPersisted) deadlines=\(stats.deadlinesPersisted) cancelledDropped=\(cancelledCount) durationMs=\(Int(Date().timeIntervalSince(attemptStart) * 1000))"
            )
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            messageProviderID = providerID
            SyncLog.append(
                "result=failure provider=\(providerID.rawValue) durationMs=\(Int(Date().timeIntervalSince(attemptStart) * 1000)) error=\(error.localizedDescription)"
            )
        }
    }

    private func attachProviderProgressCallback(
        providerID: ProviderID,
        provider: any TravelProvider
    ) {
        if providerID == .check24, let check24 = provider as? Check24TravelProvider {
            check24.onProgress = { [weak self] message in
                self?.messageProviderID = providerID
                self?.statusMessage = message
            }
        } else if providerID == .opodo, let opodo = provider as? OpodoTravelProvider {
            opodo.onProgress = { [weak self] message in
                self?.messageProviderID = providerID
                self?.statusMessage = message
            }
        } else if providerID == .booking, let booking = provider as? BookingComTravelProvider {
            booking.onProgress = { [weak self] message in
                self?.messageProviderID = providerID
                self?.statusMessage = message
            }
        } else if providerID == .airbnb, let airbnb = provider as? AirbnbTravelProvider {
            airbnb.onProgress = { [weak self] message in
                self?.messageProviderID = providerID
                self?.statusMessage = message
            }
        }
    }

    private func enrichDraftsIfNeeded(
        providerID: ProviderID,
        provider: any TravelProvider,
        session: any ProviderSession,
        requiresDeadlines: Bool,
        drafts: inout [ProviderBookingDraft]
    ) async throws {
        for i in drafts.indices {
            guard drafts[i].status != .cancelled else { continue }
            guard let externalUrl = drafts[i].externalUrl else { continue }

            let needsDeadlineEnrichment = requiresDeadlines && drafts[i].deadlines.isEmpty
            let needsBookingComDeadlineRefine = providerID == .booking
            let needsStatusProbe = providerID == .opodo
            let needsAirbnbEnrichment = providerID == .airbnb
            guard needsDeadlineEnrichment || needsBookingComDeadlineRefine || needsStatusProbe || needsAirbnbEnrichment else {
                continue
            }

            let ref = ProviderBookingRef(
                externalUrl: externalUrl,
                bookingType: drafts[i].bookingType,
                hotelOffsetSeconds: drafts[i].hotelOffsetSeconds
            )
            let enrichment = try await provider.enrichBooking(session: session, ref: ref)

            drafts[i].status = enrichment.status ?? drafts[i].status

            // Präzisere Enrichment-Fristen überschreiben grobe Katalog-Policy,
            // aber nur wenn der Provider wirklich Fristen liefert.
            if !enrichment.deadlines.isEmpty {
                drafts[i].deadlines = enrichment.deadlines
            }

            // Replace-Strategy: Passagiere/Gepäck hängen an Flight-Tripdetails
            // und müssen vollständig durch das Enrichment überschrieben werden.
            drafts[i].passengers = enrichment.passengers ?? drafts[i].passengers

            drafts[i].rateDetails = Self.mergeRateDetails(
                existing: drafts[i].rateDetails,
                incoming: enrichment.rateDetails
            )
            drafts[i].hotelOffsetSeconds = enrichment.hotelOffsetSeconds ?? drafts[i].hotelOffsetSeconds
            drafts[i].hotelCheckInMinutes = enrichment.hotelCheckInMinutes ?? drafts[i].hotelCheckInMinutes
            drafts[i].hotelCheckOutMinutes = enrichment.hotelCheckOutMinutes ?? drafts[i].hotelCheckOutMinutes
            drafts[i].flightDepartureOffsetSeconds = enrichment.flightDepartureOffsetSeconds
                ?? drafts[i].flightDepartureOffsetSeconds
            drafts[i].flightArrivalOffsetSeconds = enrichment.flightArrivalOffsetSeconds
                ?? drafts[i].flightArrivalOffsetSeconds
        }
    }

    private func assignTripsAfterNormalization(
        bookingRepo: SwiftDataBookingRepository,
        tripRepo: SwiftDataTripRepository
    ) throws {
        let nowForAssignment = Date()
        var bookingsMutable = try bookingRepo.fetchAll()
        var bookingsByID: [UUID: Int] = [:]
        for (index, booking) in bookingsMutable.enumerated() {
            bookingsByID[booking.id] = index
        }

        let trips = try tripRepo.fetchAll()
        let assignment = TripBookingAssignment()

        for trip in trips {
            let ids = assignment.assignableBookingIDs(
                bookings: bookingsMutable,
                trip: trip,
                now: nowForAssignment
            )
            for bookingID in ids {
                try tripRepo.assignBooking(bookingID: bookingID, toTripID: trip.id)
                if let idx = bookingsByID[bookingID] {
                    bookingsMutable[idx].tripID = trip.id
                }
            }
        }

        try tripRepo.save()
    }

    private func maybeScheduleAndSyncCalendars(
        settings: AppSettings,
        bookings: [Booking],
        deadlines: [CancellationDeadline],
        bookingTitles: [UUID: String],
        bookingRepo: SwiftDataBookingRepository
    ) async throws {
        if settings.notificationEnabled {
            statusMessage = "Plane Erinnerungen…"
            _ = try await reminderScheduler.scheduleCancellationDeadlines(
                deadlines: deadlines,
                bookingTitles: bookingTitles,
                leadTimesDays: settings.leadTimesDays
            )
        }

        if settings.eventKitEnabled {
            statusMessage = "Schreibe Kalender…"

            let tripRepo = SwiftDataTripRepository(modelContext: modelContext)
            let trips = try tripRepo.fetchAll()

            // Standard-Verhalten:
            // Wenn der Nutzer den globalen Standardkalender "Reisen" (und die Standard-Reminder-Liste "Reisen")
            // in der Fix/Global-Strategie ausgewählt hat, sollen diese bei Bedarf automatisch erstellt werden,
            // damit der Sync nicht nur an "Kalender existiert nicht" scheitert.
            let standardCalendarTitle = "Reisen"
            let effectiveEventCreateIfMissing =
                settings.eventCalendarCreateIfMissing ||
                (settings.calendarTitleMode == .fixed && settings.calendarTitle == standardCalendarTitle)
            let effectiveReminderCreateIfMissing =
                settings.reminderCalendarCreateIfMissing ||
                (settings.calendarTitleMode == .fixed && settings.reminderCalendarTitle == standardCalendarTitle)

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
        }

        if settings.eventKitEnabled,
           settings.calendarTripTimesEnabled || settings.calendarFlightTimesEnabled || settings.calendarHotelStaysEnabled {
            statusMessage = "Schreibe Reisezeiten…"

            var bookingsMutable = bookings

            // Ensure location address fields are persisted before we compose calendar events.
            // This keeps the EventKit sync purely data-driven (no best-effort UI guessing in the bridge).
            let needsTripAddresses = settings.calendarTripTimesEnabled
            let needsHotelAddresses = settings.calendarTripTimesEnabled || settings.calendarHotelStaysEnabled
            let needsFlightAddresses = settings.calendarFlightTimesEnabled

            if needsTripAddresses || needsFlightAddresses {
                statusMessage = "Löse Adressen auf…"
                try await resolveAndPersistBookingAddressesIfNeeded(
                    needsHotelAddresses: needsHotelAddresses,
                    needsFlightAddresses: needsFlightAddresses,
                    bookings: &bookingsMutable,
                    bookingRepo: bookingRepo
                )
            }

            let tripRepo = SwiftDataTripRepository(modelContext: modelContext)
            let trips = try tripRepo.fetchAll()

            try await calendarSync.syncTripTimelineEntries(
                trips: trips,
                bookings: bookingsMutable,
                bookingTitles: bookingTitles,
                eventCalendarTitle: settings.calendarTitle,
                eventCreateIfMissing:
                    settings.eventCalendarCreateIfMissing ||
                    (settings.calendarTitleMode == .fixed && settings.calendarTitle == "Reisen"),
                includeTripStartEnd: settings.calendarTripTimesEnabled,
                includeFlightTimes: settings.calendarFlightTimesEnabled,
                includeHotelStays: settings.calendarHotelStaysEnabled
            )
        }
    }

    private func resolveAndPersistBookingAddressesIfNeeded(
        needsHotelAddresses: Bool,
        needsFlightAddresses: Bool,
        bookings: inout [Booking],
        bookingRepo: SwiftDataBookingRepository
    ) async throws {
        // Aufgabe: Nur die relevanten Address-Felder ergänzen, wenn sie fehlen.
        // Durch Caching reduzieren wir die Anzahl der Geocoding-Requests.
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

    /// Status/Fehler dieses Providers verwerfen (z. B. beim Wegnavigieren).
    public func dismissMessages(for providerID: ProviderID) {
        if syncingProviderID == providerID { return }
        guard messageProviderID == providerID else { return }
        statusMessage = nil
        errorMessage = nil
        messageProviderID = nil
    }

    /// Synchronisiert alle angegebenen Provider nacheinander (HIG: eine laufende Aktion, klarer Fortschritt).
    public func syncAll(
        providers: [(ProviderID, WKWebView)],
        settings: AppSettings
    ) async {
        guard !isSyncing else { return }
        guard !providers.isEmpty else {
            errorMessage = "Keine angemeldeten Provider zum Synchronisieren."
            statusMessage = nil
            messageProviderID = nil
            return
        }

        var successCount = 0
        var failureCount = 0
        var lastError: String?

        for (index, item) in providers.enumerated() {
            let (providerID, webView) = item
            statusMessage = "Synchronisiere \(index + 1)/\(providers.count)…"
            messageProviderID = providerID
            errorMessage = nil

            await sync(providerID: providerID, webView: webView, settings: settings)

            if let errorMessage {
                failureCount += 1
                lastError = errorMessage
            } else {
                successCount += 1
            }
        }

        messageProviderID = nil
        if failureCount == 0 {
            errorMessage = nil
            statusMessage = "Alle Provider synchronisiert (\(successCount))."
        } else {
            errorMessage = lastError
            statusMessage = "Sync beendet: \(successCount) ok, \(failureCount) fehlgeschlagen."
        }
    }

    private func providerIsEnabled(_ providerID: ProviderID) -> Bool {
        let key = AppSettingsKeys.providerEnabledKey(for: providerID)

        // Default: alle Provider aktiv, solange der User nichts deaktiviert hat.
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Enrichment füllt fehlende Felder; bestehende Werte (z. B. Katalogpreis) bleiben,
    /// wenn Enrichment sie bewusst weglässt (nil).
    private static func mergeRateDetails(
        existing: BookingRateDetails?,
        incoming: BookingRateDetails?
    ) -> BookingRateDetails? {
        guard let incoming else { return existing }
        guard let existing else { return incoming }

        var merged = existing
        assignOptional(incoming.rawDetailsFingerprint, into: &merged, \.rawDetailsFingerprint)
        assignOptional(incoming.totalPriceAmount, into: &merged, \.totalPriceAmount)
        assignOptional(incoming.totalPriceCurrency, into: &merged, \.totalPriceCurrency)
        assignOptional(incoming.roomCategory, into: &merged, \.roomCategory)
        assignOptional(incoming.includedBreakfast, into: &merged, \.includedBreakfast)
        assignOptional(incoming.guestCount, into: &merged, \.guestCount)
        assignOptional(incoming.roomCount, into: &merged, \.roomCount)
        assignOptional(incoming.airline, into: &merged, \.airline)
        assignOptional(incoming.passengerCount, into: &merged, \.passengerCount)
        assignOptional(incoming.baggageInfoRaw, into: &merged, \.baggageInfoRaw)
        assignOptional(incoming.lastParsedAt, into: &merged, \.lastParsedAt)
        assignNonEmptyRoomItems(incoming.roomItems, into: &merged)
        return merged
    }

    private static func assignOptional<T>(
        _ incoming: T?,
        into target: inout BookingRateDetails,
        _ keyPath: WritableKeyPath<BookingRateDetails, T?>
    ) {
        guard let incoming else { return }
        target[keyPath: keyPath] = incoming
    }

    private static func assignIfBoardTypeKnown(
        _ incoming: BookingBoardType,
        into target: inout BookingRateDetails
    ) {
        guard incoming != .unknown else { return }
        target.boardType = incoming
    }

    private static func assignNonEmptyRoomItems(
        _ incoming: [BookingRoomItem],
        into target: inout BookingRateDetails
    ) {
        guard !incoming.isEmpty else { return }
        target.roomItems = incoming
    }
}

public enum SyncLog {
    public static func append(_ line: String) {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let base = appSupport.appendingPathComponent("Reisen", isDirectory: true)
        let logURL = base.appendingPathComponent("sync-log.txt")
        do {
            try fm.createDirectory(at: base, withIntermediateDirectories: true)
            let fullLine = "[\(ISO8601DateFormatter().string(from: Date()))] \(line)\n"
            if let data = fullLine.data(using: .utf8) {
                if fm.fileExists(atPath: logURL.path) {
                    let handle = try FileHandle(forWritingTo: logURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: logURL, options: [.atomic])
                }
            }
        } catch {
            // Logging must not mask sync errors; surface via stderr in debug.
            #if DEBUG
            print("[Reisen] Sync-Log fehlgeschlagen: \(error)")
            #endif
        }
    }
}

