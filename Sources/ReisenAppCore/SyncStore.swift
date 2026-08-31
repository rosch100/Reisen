import Foundation
import OSLog
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

    nonisolated package static func bannerMessage(from error: Error) -> String {
        error.localizedDescription
    }

    private func assignError(_ error: Error, clearStatus: Bool) {
        let mapped = UserNotificationAuthorization.mapped(error)
        errorMessage = Self.bannerMessage(from: mapped)
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
    static let maxFileBytes = 262_144
    static let keepBytes = 65_536
    private static let fileAccessLock = NSLock()
    private static let logger = Logger(
        subsystem: "de.reisen.Reisen",
        category: "sync-log"
    )

    static func fileURL() -> URL? {
        PersistenceBootstrap.supportDirectoryURL()?
            .appendingPathComponent("sync-log.txt")
    }

    @discardableResult
    public static func append(_ line: String) -> Bool {
        append(line, to: fileURL(), now: Date())
    }

    @discardableResult
    static func append(_ line: String, to url: URL?, now: Date) -> Bool {
        fileAccessLock.lock()
        defer { fileAccessLock.unlock() }
        let fm = FileManager.default
        guard let logURL = url else {
            logger.error("Sync-Log-Ziel ist nicht verfügbar.")
            return false
        }
        let base = logURL.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: base, withIntermediateDirectories: true)
            let fullLine = "[\(ISO8601DateFormatter().string(from: now))] \(line)\n"
            guard let data = fullLine.data(using: .utf8) else {
                logger.error("Sync-Log konnte nicht als UTF-8 kodiert werden.")
                return false
            }
            if fm.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                defer {
                    do {
                        try handle.close()
                    } catch {
                        logger.error("Sync-Log-Datei konnte nicht geschlossen werden.")
                    }
                }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: logURL, options: [.atomic])
            }
            return rotateIfNeeded(at: logURL)
        } catch {
            logger.error(
                "Sync-Log fehlgeschlagen: \(error.localizedDescription, privacy: .private)"
            )
            return false
        }
    }

    @discardableResult
    static func rotateIfNeeded(at url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            guard data.count > maxFileBytes else { return true }
            let suffix = data.suffix(keepBytes)
            try suffix.write(to: url, options: [.atomic])
            return true
        } catch {
            logger.error(
                "Sync-Log-Rotation fehlgeschlagen: \(error.localizedDescription, privacy: .private)"
            )
            return false
        }
    }

    static func recentTail(
        maxBytes: Int = DiagnosticLogAttachment.attachMaxRawBytes,
        fileURL: URL? = nil,
        includeLocalDebug: Bool = false
    ) -> DiagnosticLogAttachment {
        guard let url = fileURL ?? Self.fileURL() else { return .missing }
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return .missing }
        do {
            let data = try Data(contentsOf: url)
            if data.isEmpty { return .empty }
            let fileByteCount = data.count
            let tailData = data.suffix(maxBytes)
            let rawTail = String(decoding: tailData, as: UTF8.self)
            let tail = includeLocalDebug ? rawTail : exportableTail(from: rawTail)
            let redacted = SecretRedactor.redact(tail)
            return DiagnosticLogAttachment.makeAttached(
                redactedTail: redacted,
                fileByteCount: fileByteCount,
                truncated: fileByteCount > maxBytes
            )
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }

    private static func exportableTail(from tail: String) -> String {
        tail.split(separator: "\n", omittingEmptySubsequences: false)
            .filter(isExportableLine)
            .joined(separator: "\n")
    }

    private static func isExportableLine(_ line: Substring) -> Bool {
        guard let markerRange = line.range(of: "diagnostic=") else { return true }
        let payload = line[markerRange.upperBound...]
        guard let data = payload.data(using: .utf8),
              let event = try? JSONDecoder().decode(DiagnosticEvent.self, from: data)
        else {
            return false
        }
        return event.visibility == .publicDiagnostic
    }

    static func removeExpiredDiagnosticEvents(
        olderThan cutoff: Date,
        fileURL: URL
    ) throws {
        fileAccessLock.lock()
        defer { fileAccessLock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let retainedLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                guard let markerRange = line.range(of: "diagnostic=") else { return true }
                let payload = line[markerRange.upperBound...]
                guard let data = payload.data(using: .utf8),
                      let event = try? JSONDecoder().decode(DiagnosticEvent.self, from: data)
                else {
                    return true
                }
                return event.timestamp >= cutoff
            }
        try Data(retainedLines.joined(separator: "\n").utf8)
            .write(to: fileURL, options: [.atomic])
    }
}
