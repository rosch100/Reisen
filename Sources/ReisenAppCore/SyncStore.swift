import Foundation
import Observation
import SwiftData

import ReisenDomain
import ReisenData

@MainActor
@Observable
public final class SyncStore {
    public var isSyncing = false
    public var syncingProviderID: ProviderID?
    /// Welcher Provider die aktuelle Status-/Fehlermeldung erzeugt hat.
    public var messageProviderID: ProviderID?
    public var errorMessage: String?
    public var statusMessage: String?
    /// Öffentliche GitHub-Issue-URL zum letzten gemeldeten Fehler.
    public var lastPublicIssueURL: URL?
    /// `false`, wenn nur auf ein bestehendes Issue verwiesen wird (Kommentar-Throttle).
    public var lastPublicIssueDidPostUpdate = true
    /// Expliziter Fehler, wenn das öffentliche Issue nicht angelegt werden konnte.
    public var issueReportErrorMessage: String?
    /// Datenschutz-Pane, falls `errorMessage` eine verweigerte Sicherheitsoption ist.
    public var privacySettingPane: PrivacySettingPane?
    /// Optionale Freigaben, die beim letzten Provider-Sync übersprungen wurden (für Sync-All-Aggregation).
    package var lastSyncSkippedPrivacyPanes: [PrivacySettingPane] = []
    /// Abschluss des letzten Provider-Syncs (für Sync-All-Aggregation).
    package var lastProviderSyncFinishOutcome: ProviderSyncFinishOutcome?

    package let modelContext: ModelContext
    package let registry: ProviderRegistry
    private let sideEffects: LocalSideEffectCoordinator
    private let issueReporter: SyncIssueReporter

    public init(modelContext: ModelContext, registry: ProviderRegistry) {
        self.modelContext = modelContext
        self.registry = registry
        self.sideEffects = LocalSideEffectCoordinator(modelContext: modelContext)
        self.issueReporter = SyncIssueReporter()
        self.issueReporter.onUpdate = { [weak self] url, didPost, issueError in
            guard let self else { return }
            self.lastPublicIssueURL = url
            self.lastPublicIssueDidPostUpdate = didPost
            self.issueReportErrorMessage = issueError
        }
    }

    /// Rebuild EventKit/Reminders after CloudKit imports or app activation (device-local side effects).
    public func rebuildLocalSideEffects(
        settings: AppSettings = .fromUserDefaults(),
        announceProgress: Bool = false
    ) async {
        await sideEffects.rebuildLocalSideEffects(
            isSyncing: isSyncing,
            settings: settings,
            announceProgress: announceProgress,
            setStatusMessage: { [weak self] message in self?.statusMessage = message },
            handleError: { [weak self] error, clearStatus in
                self?.assignError(error, clearStatus: clearStatus)
            },
            clearMessageProvider: { [weak self] in self?.messageProviderID = nil }
        )
    }

    /// Observe CloudKit/remote store merges and rebuild local EventKit/Reminder links.
    public func startObservingCloudSideEffects() {
        sideEffects.startObservingCloudSideEffects(
            isSyncing: { [weak self] in self?.isSyncing == true },
            onRemoteChange: { [weak self] in
                await self?.rebuildLocalSideEffects(announceProgress: false)
            }
        )
    }

    public func stopObservingCloudSideEffects() {
        sideEffects.stopObservingCloudSideEffects()
    }

    /// Status/Fehler dieses Providers verwerfen (z. B. beim Wegnavigieren).
    public func dismissMessages(for providerID: ProviderID) {
        if syncingProviderID == providerID { return }
        guard messageProviderID == providerID else { return }
        statusMessage = nil
        clearSyncError()
        messageProviderID = nil
    }

    package func setSyncFailure(_ error: Error, clearStatus: Bool) {
        assignError(error, clearStatus: clearStatus)
    }

    package func setSyncFailureMessage(_ message: String) {
        assignErrorMessage(message)
    }

    package func clearSyncError() {
        clearError()
    }

    package func assignTripsAfterNormalization(
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

    package func scheduleSideEffectsFromStore(
        settings: AppSettings,
        announceProgress: Bool
    ) async throws -> [PrivacySettingPane] {
        try await sideEffects.scheduleAndSyncFromStore(
            settings: settings,
            announceProgress: announceProgress,
            setStatusMessage: { [weak self] message in self?.statusMessage = message }
        )
    }

    private func assignError(_ error: Error, clearStatus: Bool) {
        let mapped = UserNotificationAuthorization.mapped(error)
        errorMessage = mapped.localizedDescription
        privacySettingPane = PrivacyAccessDenial.pane(from: mapped)
        if clearStatus {
            statusMessage = nil
        }
        issueReporter.scheduleIfNeeded(error: mapped, providerID: messageProviderID)
    }

    private func assignErrorMessage(_ message: String) {
        errorMessage = message
        privacySettingPane = nil
        statusMessage = nil
        issueReporter.scheduleIfNeeded(message: message, providerID: messageProviderID)
    }

    private func clearError() {
        errorMessage = nil
        privacySettingPane = nil
        issueReporter.reset()
    }
}

public enum SyncLog {
    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Reisen", isDirectory: true)
            .appendingPathComponent("sync-log.txt")
    }

    public static func append(_ line: String) {
        let fm = FileManager.default
        guard let logURL = fileURL else { return }
        let base = logURL.deletingLastPathComponent()
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
            #if DEBUG
            print("[Reisen] Sync-Log fehlgeschlagen: \(error)")
            #endif
        }
    }
}
