import Foundation
import WebKit
import SwiftData

import ReisenAppCore
import ReisenData
import ReisenDomain
import ReisenProviders

extension SyncStore {
    public func sync(
        providerID: ProviderID,
        webView: WKWebView,
        settings: AppSettings,
        navigationHintURLs: [URL] = [],
        holdsSyncLock: Bool = true
    ) async {
        lastSyncSkippedPrivacyPanes = []
        lastProviderSyncFinishOutcome = nil

        guard AppSettingsKeys.isProviderEnabled(providerID) else {
            setSyncFailureMessage(L10n.format(.syncProviderDisabled, providerID.rawValue))
            messageProviderID = providerID
            return
        }

        beginProviderSync(providerID, holdsSyncLock: holdsSyncLock)
        defer { endProviderSync(holdsSyncLock: holdsSyncLock) }

        let attemptStart = Date()
        let snapshot: PersistedSyncSnapshot

        do {
            snapshot = try await persistProviderCatalog(
                providerID: providerID,
                webView: webView,
                navigationHintURLs: navigationHintURLs,
                settings: settings,
                attemptStart: attemptStart
            )
        } catch {
            failProviderSync(
                providerID: providerID,
                attemptStart: attemptStart,
                error: error
            )
            return
        }

        do {
            let skippedPrivacy = try await scheduleSideEffectsFromStore(
                settings: settings,
                announceProgress: true
            )
            finishPersistedSync(snapshot, .success(skippedPrivacy: skippedPrivacy))
        } catch {
            if let pane = PrivacyOptionalCapability.deniedPane(from: error) {
                finishPersistedSync(snapshot, .privacyRestricted(pane))
                return
            }
            finishPersistedSync(snapshot, .sideEffectFailure(error))
        }
    }

    public func syncAll(
        providers: [(ProviderID, WKWebView)],
        settings: AppSettings,
        resolveNavigationHintURLs: @escaping (ProviderID) -> [URL] = { _ in [] }
    ) async {
        guard !isSyncing else { return }
        guard !providers.isEmpty else {
            setSyncFailureMessage(L10n.string(.syncNoLoggedInProviders))
            messageProviderID = nil
            return
        }

        isSyncing = true
        defer {
            isSyncing = false
            syncingProviderID = nil
        }

        var aggregation = SyncAllAggregation()

        for (index, (providerID, webView)) in providers.enumerated() {
            let outcome = await syncAllProvider(
                at: index,
                total: providers.count,
                providerID: providerID,
                webView: webView,
                settings: settings,
                navigationHintURLs: resolveNavigationHintURLs(providerID)
            )
            aggregation.recordProviderRun(outcome)
        }

        applySyncAllFinish(aggregation)
    }

    private func syncAllProvider(
        at index: Int,
        total: Int,
        providerID: ProviderID,
        webView: WKWebView,
        settings: AppSettings,
        navigationHintURLs: [URL]
    ) async -> ProviderSyncRunOutcome {
        statusMessage = L10n.format(.syncProgressIndex, index + 1, total)
        messageProviderID = providerID
        clearSyncError()

        await sync(
            providerID: providerID,
            webView: webView,
            settings: settings,
            navigationHintURLs: navigationHintURLs,
            holdsSyncLock: false
        )

        return captureProviderSyncRun(providerName: providerID.displayName)
    }

    private func captureProviderSyncRun(providerName: String) -> ProviderSyncRunOutcome {
        ProviderSyncRunOutcome(
            providerName: providerName,
            errorMessage: errorMessage,
            finishOutcome: lastProviderSyncFinishOutcome,
            privacyPane: privacySettingPane,
            skippedPanes: lastSyncSkippedPrivacyPanes
        )
    }

    private func applySyncAllFinish(_ aggregation: SyncAllAggregation) {
        messageProviderID = nil
        switch aggregation.finishPresentation {
        case .hasFailures(let errorDetails, let privacyPane, let completionLine):
            errorMessage = errorDetails
            privacySettingPane = privacyPane
            statusMessage = completionLine
        case .allSucceeded(let baseLine, let skippedPrivacy):
            clearSyncError()
            statusMessage = PrivacyOptionalCapability.statusLine(
                base: baseLine,
                skipped: skippedPrivacy
            )
        }
    }
}

private extension SyncStore {
    struct PersistedSyncSnapshot {
        let providerID: ProviderID
        let stats: SyncProviderBookingsResult
        let cancelledCount: Int
        let missingDeadlinesHint: Bool
        let attemptStart: Date

        var statusBaseLine: String {
            stats.persistedSyncStatusLine(missingDeadlinesHint: missingDeadlinesHint)
        }

        var cancelledDroppedLogSuffix: String {
            "cancelledDropped=\(cancelledCount)"
        }
    }

    enum PersistedSyncFinish {
        case success(skippedPrivacy: [PrivacySettingPane])
        case privacyRestricted(PrivacySettingPane)
        case sideEffectFailure(Error)
    }

    func beginProviderSync(_ providerID: ProviderID, holdsSyncLock: Bool) {
        syncingProviderID = providerID
        messageProviderID = providerID
        if holdsSyncLock {
            isSyncing = true
        }
        clearSyncError()
        statusMessage = L10n.string(.syncProgress)
    }

    func endProviderSync(holdsSyncLock: Bool) {
        if holdsSyncLock {
            isSyncing = false
        }
        syncingProviderID = nil
    }

    func persistProviderCatalog(
        providerID: ProviderID,
        webView: WKWebView,
        navigationHintURLs: [URL],
        settings: AppSettings,
        attemptStart: Date
    ) async throws -> PersistedSyncSnapshot {
        guard let provider = registry.provider(id: providerID) else {
            throw RepositoryError.invalidState(L10n.format(.syncProviderUnavailable, providerID.rawValue))
        }

        attachProviderProgressCallback(providerID: providerID, provider: provider)

        let session = provider.makeSyncSession(
            webView: webView,
            navigationHintURLs: navigationHintURLs
        )

        let catalog = try await provider.fetchCatalog(session: session)

        var drafts = catalog.bookings
        let requiresDeadlines = settings.requiresDeadlineEnrichment
        try await enrichDraftsIfNeeded(
            provider: provider,
            session: session,
            requiresDeadlines: requiresDeadlines,
            drafts: &drafts
        )

        let (activeDrafts, cancelledCount) = drafts.partitionedByCancellation()
        let missingDeadlinesHint = activeDrafts.missingDeadlinesHint(requiresDeadlines: requiresDeadlines)
        Self.logBookingEnrichmentDiagnostics(
            providerID: providerID,
            activeDrafts: activeDrafts,
            missingDeadlinesHint: missingDeadlinesHint
        )

        let bookingRepo = SwiftDataBookingRepository(modelContext: modelContext)
        let tripRepo = SwiftDataTripRepository(modelContext: modelContext)
        statusMessage = L10n.string(.syncSaving)
        let stats = try SyncProviderBookings(bookingRepository: bookingRepo).execute(
            provider: providerID,
            drafts: activeDrafts,
            requiresDeadlines: false
        )

        try await FlightTimeZoneAssigner(bookingRepository: bookingRepo).assignMissingOffsets()
        try TimeNormalizationRepair(bookingRepository: bookingRepo).repairIfNeeded()
        try assignTripsAfterNormalization(bookingRepo: bookingRepo, tripRepo: tripRepo)

        return PersistedSyncSnapshot(
            providerID: providerID,
            stats: stats,
            cancelledCount: cancelledCount,
            missingDeadlinesHint: missingDeadlinesHint,
            attemptStart: attemptStart
        )
    }

    func finishPersistedSync(_ snapshot: PersistedSyncSnapshot, _ finish: PersistedSyncFinish) {
        clearSyncError()
        messageProviderID = snapshot.providerID
        let base = snapshot.statusBaseLine

        switch finish {
        case .success(let skippedPrivacy):
            completePersistedSync(
                snapshot,
                outcome: .fullSuccess,
                base: base,
                skippedPrivacy: skippedPrivacy,
                logResult: "success"
            )

        case .privacyRestricted(let pane):
            completePersistedSync(
                snapshot,
                outcome: .privacyRestricted,
                base: base,
                skippedPrivacy: [pane],
                logResult: "success_restricted",
                logExtra: "\(snapshot.cancelledDroppedLogSuffix) skipped=\(pane.rawValue)"
            )

        case .sideEffectFailure(let error):
            lastProviderSyncFinishOutcome = .sideEffectFailure
            lastSyncSkippedPrivacyPanes = []
            privacySettingPane = PrivacyOptionalCapability.deniedPane(from: error)
            let detail = PrivacyOptionalCapability.localizedDescription(for: error)
            let messages = SyncAllSummary.sideEffectFailureMessages(base: base, detail: detail)
            errorMessage = messages.errorMessage
            statusMessage = messages.statusMessage
            Self.logPersistedSync(
                snapshot,
                result: "success_side_effects_failed",
                extra: "\(snapshot.cancelledDroppedLogSuffix) sideEffectError=\(detail)"
            )
        }
    }

    func completePersistedSync(
        _ snapshot: PersistedSyncSnapshot,
        outcome: ProviderSyncFinishOutcome,
        base: String,
        skippedPrivacy: [PrivacySettingPane],
        logResult: String,
        logExtra: String? = nil
    ) {
        lastProviderSyncFinishOutcome = outcome
        lastSyncSkippedPrivacyPanes = skippedPrivacy
        statusMessage = PrivacyOptionalCapability.statusLine(base: base, skipped: skippedPrivacy)
        Self.logPersistedSync(
            snapshot,
            result: logResult,
            extra: logExtra ?? snapshot.cancelledDroppedLogSuffix
        )
    }

    func failProviderSync(providerID: ProviderID, attemptStart: Date, error: Error) {
        lastProviderSyncFinishOutcome = nil
        setSyncFailure(error, clearStatus: true)
        messageProviderID = providerID
        SyncLog.append(
            "result=failure provider=\(providerID.rawValue) durationMs=\(Self.durationMs(since: attemptStart)) error=\(error.localizedDescription)"
        )
    }

    func attachProviderProgressCallback(providerID: ProviderID, provider: any TravelProvider) {
        guard let reporting = provider as? any TravelProviderProgressReporting else { return }
        reporting.onProgress = { [weak self] message in
            self?.messageProviderID = providerID
            self?.statusMessage = message
        }
    }

    func enrichDraftsIfNeeded(
        provider: any TravelProvider,
        session: any ProviderSession,
        requiresDeadlines: Bool,
        drafts: inout [ProviderBookingDraft]
    ) async throws {
        for index in drafts.indices {
            guard drafts[index].status != .cancelled else { continue }
            guard let ref = drafts[index].enrichmentRef else { continue }
            guard provider.needsDraftEnrichment(
                draft: drafts[index],
                requiresDeadlines: requiresDeadlines
            ) else { continue }

            let enrichment = try await provider.enrichBooking(session: session, ref: ref)
            drafts[index].apply(enrichment)
        }
    }

    static func logBookingEnrichmentDiagnostics(
        providerID: ProviderID,
        activeDrafts: [ProviderBookingDraft],
        missingDeadlinesHint: Bool
    ) {
        guard providerID == .booking else { return }
        let hotels = activeDrafts.filter { $0.bookingType == .hotel }
        let withDeadlines = activeDrafts.filter { !$0.deadlines.isEmpty }.count
        let hotelURLSample = hotels.first?.externalUrl.map { String($0.prefix(120)) } ?? "-"
        SyncLog.append(
            "enrich_deadlines provider=booking active=\(activeDrafts.count) hotels=\(hotels.count) withDeadlines=\(withDeadlines) missingHint=\(missingDeadlinesHint) hotelUrl=\(hotelURLSample)"
        )
    }

    static func logPersistedSync(
        _ snapshot: PersistedSyncSnapshot,
        result: String,
        extra: String
    ) {
        SyncLog.append(
            "result=\(result) provider=\(snapshot.providerID.rawValue) bookings=\(snapshot.stats.bookingsPersisted) deadlines=\(snapshot.stats.deadlinesPersisted) durationMs=\(durationMs(since: snapshot.attemptStart)) \(extra)"
        )
    }

    static func durationMs(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
