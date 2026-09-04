import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenAppCore
import ReisenProviderSync
import ReisenSharedUI
import ReisenPasteImport
import ReisenDiagnostics
import AppKit
import Foundation
import WebKit

private enum ContentSelectionBatchDeleteError: LocalizedError {
    case bookingMissing
    case tripMissing

    var errorDescription: String? {
        switch self {
        case .bookingMissing:
            return L10n.string(.tripBookingMissing)
        case .tripMissing:
            return L10n.string(.tripTripMissing)
        }
    }
}

private struct ContentSelectionBatchDeleteDialogs: ViewModifier {
    @Binding var openBookingIDs: Set<UUID>
    @Binding var showOpenBookings: Bool
    @Binding var tripIDs: Set<UUID>
    @Binding var showTrips: Bool
    let deleteOpenBookings: () -> Void
    let deleteTrips: (TripDeletionBookingPolicy) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.format(.tripSelectedOpenBookings, openBookingIDs.count),
                isPresented: $showOpenBookings,
                titleVisibility: .visible
            ) {
                Button(L10n.string(.commonDelete), role: .destructive, action: deleteOpenBookings)
                Button(L10n.string(.commonCancel), role: .cancel) {
                    openBookingIDs = []
                }
            }
            .confirmationDialog(
                L10n.string(.actionDeleteTrip),
                isPresented: $showTrips,
                titleVisibility: .visible
            ) {
                Button(L10n.string(.tripDeleteWithBookings), role: .destructive) {
                    deleteTrips(.deleteContained)
                }
                Button(L10n.string(.tripDeleteKeepBookings)) {
                    deleteTrips(.keepAsOpen)
                }
                Button(L10n.string(.commonCancel), role: .cancel) {
                    tripIDs = []
                }
            } message: {
                Text(L10n.format(.tripSelectedTrips, tripIDs.count))
            }
    }
}

struct ContentView: View {
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @State private var selection: SidebarSelection?
    @State private var expandedTripIDs: Set<UUID> = []
    /// Offene-/Abgelaufen-Mailbox standardmäßig aufgeklappt (Liste sichtbar; Nutzer kann einklappen).
    @State private var expandedOpenMailbox = true
    @State private var expandedElapsedOpenMailbox = true
    @State private var didInitExpanded = false
    @State private var didRunTimeRepair = false
    @State private var didApplyInitialSelection = false
    @State private var sessionProbeFinished = UITestingLaunch.isActive
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncStore) private var store
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.openURL) private var openURL

    @State private var providerEnableEpoch = 0
    @State private var showProviderSetup = false
    @State private var didRecordProviderSetupPresented = false
    @State private var showCreateTrip = false
    @State private var tripToEdit: SDTrip?
    @State private var tripPendingDelete: SDTrip?
    @State private var showTripDeleteConfirmation = false
    @State private var pendingDeleteTripIDs: Set<UUID> = []
    @State private var showTripBatchDeleteConfirmation = false
    @State private var pendingDeleteOpenBooking: SDBooking?
    @State private var showOpenBookingDeleteConfirmation = false
    @State private var pendingDeleteOpenBookingIDs: Set<UUID> = []
    @State private var showOpenBookingBatchDeleteConfirmation = false
    @State private var persistErrorMessage: String?
    @State private var cancelRequest: BookingPortalCancelRequest?

    /// Selektion der mittleren Buchungsliste → rechte Detailspalte.
    @State private var selectedTimelineIDs: Set<String> = []
    @State private var timelineSelectionAnchor: String?
    @State private var bookingEditorSession: BookingEditorSession? = nil
    /// Getippter Titel während Create — live in Draft-Zeilen (leer = „Neue Buchung“).
    @State private var createDraftTypedTitle = ""
    /// Payload des aktiven Gap-Editors (Sheet in Detailspalte).
    @State private var gapEditorPayload: GapEditorPayload? = nil

    @State private var activeTripID: UUID? = nil

    /// Auswahl der offenen Buchung (Content → Detail, analog zu Mail-UX).
    @State private var selectedOpenBookingIDs: Set<UUID> = []
    @State private var openSelectionAnchor: UUID?
    @State private var selectedTripIDs: Set<UUID> = []
    @State private var tripSelectionAnchor: UUID?
    @State private var tripCreateSeed: TripCreateSeed?
    @State private var showCreateTripFromBookingsFailed = false

    /// Paste-Import: Lauf-Zustand; Review läuft im eigenen Fenster (Presenter).
    @State private var pasteImport = PasteImportSession()
    @State private var pasteImportReviewQueue = PasteImportReviewQueue()
    @State private var didInjectPasteImportFixture = false
    @Environment(\.openWindow) private var openWindow

    /// HIG: Spalten per dünnem Divider ziehbar (keine sichtbaren Slider-Knöpfe).
    private let sidebarMinWidth: CGFloat = 180
    private let sidebarMaxWidth: CGFloat = 420
    private let bookingListMinWidth: CGFloat = 280
    private let detailMinWidth: CGFloat = 280

    @AppStorage(AppSettingsKeys.notificationEnabled) private var notificationEnabled: Bool = true
    @AppStorage(AppSettingsKeys.eventKitEnabled) private var eventKitEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitle) private var calendarTitle: String = "Voyenna"
    @AppStorage(AppSettingsKeys.reminderCalendarTitle) private var reminderCalendarTitle: String = "Voyenna"
    @AppStorage(AppSettingsKeys.leadTimesDays) private var leadTimesDaysRaw: String = "7,3,1"
    @AppStorage(AppSettingsKeys.calendarTripTimesEnabled) private var calendarTripTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarFlightTimesEnabled) private var calendarFlightTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarHotelStaysEnabled) private var calendarHotelStaysEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitleMode) private var calendarTitleModeRaw: String = CalendarTitleMode.tripTitle.rawValue
    @AppStorage(AppSettingsKeys.eventCalendarCreateIfMissing) private var eventCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.reminderCalendarCreateIfMissing) private var reminderCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.sidebarColumnWidth) private var sidebarColumnWidth: Double = 240
    @AppStorage(AppSettingsKeys.bookingListColumnWidth) private var bookingListColumnWidth: Double = 420

    var body: some View {
        focusedContent
    }

    private var rootContent: some View {
        PersistentHorizontalSplitView(
            leftWidth: $sidebarColumnWidth,
            leftMinWidth: sidebarMinWidth,
            rightMinWidth: 560,
            leftMaxWidth: sidebarMaxWidth
        ) {
            sidebar
        } right: {
            mainColumn
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .frame(minWidth: 960, minHeight: 640)
        .onProviderEnabledChange(bump: $providerEnableEpoch) {
            sessionHub?.syncEnabledProviders(Set(enabledProviderIDs))
            presentProviderSetupIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenShowProviderSync)) { note in
            if let providerID = note.object as? ProviderID {
                selection = .providerSync(providerID)
            } else {
                selectFirstEnabledProviderSyncIfAvailable()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenSyncAllProviders)) { _ in
            Task { await runSyncAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenNewTrip)) { _ in
            showCreateTrip = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenNewTripFromOpenBookings)) { _ in
            guard selection == .openBookings, !selectedOpenBookingIDs.isEmpty else { return }
            OpenBookingCreateTripAction.assignSeed(
                fromIDs: selectedOpenBookingIDs,
                in: openBookings,
                seed: $tripCreateSeed,
                showFailed: $showCreateTripFromBookingsFailed
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenEditSelectedTrip)) { _ in
            guard case .trip(let id) = selection,
                  let trip = trips.first(where: { $0.id == id }) else { return }
            tripToEdit = trip
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenPresentBookingCancel)) { _ in
            guard let booking = selectedPortalBooking else { return }
            BookingPortalCancelRequest.present(
                for: booking,
                hasSessionWebView: sessionHub.hasSessionWebView(for: booking),
                openURL: { openURL($0) },
                setCancelRequest: { cancelRequest = $0 }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenPasteBooking)) { _ in
            pasteImport.start(
                source: PasteImportMacSource.fromPasteboard(),
                entry: pasteImportEntry,
                existing: existingDomainBookings
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenPasteBookingFromFile)) { _ in
            Task { @MainActor in
                await startPasteImportFromFile()
            }
        }
        .modifier(
            ContentViewPasteImportModifier(
                session: pasteImport,
                bookingEditorSession: $bookingEditorSession,
                onReviewQueue: advancePasteImportQueue,
                onSelectSavedBooking: selectPasteImportBooking,
                onDropped: { startPasteImport(fromDropped: $0) },
                onExternal: consumeExternalFiles
            )
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await runSyncAll() }
                } label: {
                    if store?.isSyncing == true {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.string(.actionSyncAll), systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .help(L10n.string(.actionSyncAllHelp))
                .disabled(store?.isSyncing == true || syncAllCandidates.isEmpty)

                Button {
                    showCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                }
                .help(L10n.string(.actionCreateTrip))
            }
        }
        .safeAreaInset(edge: .bottom) {
            globalSyncStatusBar
        }
        .onAppear {
            applyUITestingLaunchSelectionIfNeeded()
            presentProviderSetupIfNeeded()
            if !didInjectPasteImportFixture {
                didInjectPasteImportFixture = true
                pasteImport.injectTestingFixture()
                advancePasteImportQueue()
            }
            if !didInitExpanded {
                // Reisen standardmäßig eingeklappt; Nutzer kann aufklappen.
                expandedTripIDs = []
                didInitExpanded = true
            }

            if !didRunTimeRepair {
                didRunTimeRepair = true
                // UITesting-Seed bleibt zeitstabil; Repair würde Hotels upserten und AutoGap triggern.
                if !UITestingLaunch.isActive {
                    do {
                        let repo = SwiftDataBookingRepository(modelContext: modelContext)
                        try TimeNormalizationRepair(bookingRepository: repo).repairIfNeeded()
                    } catch {
                        #if DEBUG
                        print("[Reisen] TimeNormalizationRepair fehlgeschlagen: \(error)")
                        #endif
                    }
                }
            }
        }
        .onChange(of: selection?.tripID) { _, newTripID in
            guard newTripID != activeTripID else { return }
            activeTripID = newTripID
            selectedTimelineIDs = []
            timelineSelectionAnchor = nil
            gapEditorPayload = nil
        }
        .onChange(of: selection) { oldSelection, newSelection in
            handleSelectionChange(from: oldSelection, to: newSelection)
        }
    }

    private var sheetedContent: some View {
        rootContent
            .sheet(isPresented: $showCreateTrip) {
                TripEditorSheet(
                    mode: .create,
                    onSaved: { newTrip in
                        selection = .trip(newTrip.id)
                        showCreateTrip = false
                    }
                )
            }
            .createTripFromBookingsPresentation(
                seed: $tripCreateSeed,
                showFailed: $showCreateTripFromBookingsFailed,
                onSaved: { newTrip in
                    selection = .trip(newTrip.id)
                    tripCreateSeed = nil
                }
            )
            .sheet(item: $tripToEdit) { trip in
                TripEditorSheet(
                    mode: .edit,
                    trip: trip,
                    onSaved: { updatedTrip in
                        selection = .trip(updatedTrip.id)
                    }
                )
            }
            .sheet(isPresented: $showProviderSetup) {
                ProviderFirstLaunchSetupSheet(
                    onContinue: completeProviderSetup,
                    onLater: deferProviderSetup
                )
                .interactiveDismissDisabled(true)
            }
            .bookingPortalCancelSheet($cancelRequest)
    }

    private var confirmedContent: some View {
        sheetedContent
            .tripDeleteConfirmDialog(
                isPresented: $showTripDeleteConfirmation,
                tripTitle: tripPendingDelete?.title ?? "",
                bookingCount: tripPendingDelete?.resolvedBookings.count ?? 0,
                onKeepBookings: { performPendingTripDeletion(.keepAsOpen) },
                onDeleteBookings: { performPendingTripDeletion(.deleteContained) },
                onCancel: { tripPendingDelete = nil }
            )
            .bookingDeleteConfirmAlert(
                isPresented: $showOpenBookingDeleteConfirmation,
                bookingTitle: pendingDeleteOpenBooking?.presentationTitle ?? L10n.string(.editorBooking),
                showsSyncRestoreWarning: pendingDeleteOpenBooking.map { $0.provider != .manual } ?? false,
                onConfirm: performPendingOpenBookingDeletion,
                onCancel: { pendingDeleteOpenBooking = nil }
            )
            .modifier(
                ContentSelectionBatchDeleteDialogs(
                    openBookingIDs: $pendingDeleteOpenBookingIDs,
                    showOpenBookings: $showOpenBookingBatchDeleteConfirmation,
                    tripIDs: $pendingDeleteTripIDs,
                    showTrips: $showTripBatchDeleteConfirmation,
                    deleteOpenBookings: performPendingOpenBookingBatchDeletion,
                    deleteTrips: performPendingTripBatchDeletion
                )
            )
            .persistFailureAlert(message: $persistErrorMessage)
    }

    private var focusedContent: some View {
        confirmedContent
            .focusedSceneValue(
                \.openBookingsCommandState,
                selection == .openBookings && !selectedOpenBookingIDs.isEmpty
                    ? OpenBookingsCommandState(canCreateTripFromSelection: true)
                    : nil
            )
            .focusedSceneValue(
                \.bookingPortalOpenCommandState,
                selectedBookingPortalCommandState
            )
    }

    private func performPendingTripDeletion(_ policy: TripDeletionBookingPolicy) {
        guard let trip = tripPendingDelete else { return }
        do {
            try TripDeletion.perform(trip: trip, in: modelContext, bookings: policy)
        } catch {
            persistErrorMessage = error.localizedDescription
            return
        }
        if selection == .trip(trip.id) {
            selectedTripIDs.remove(trip.id)
            if let fallback = trips.first(where: { $0.id != trip.id }) {
                selectedTripIDs = [fallback.id]
                tripSelectionAnchor = fallback.id
                selection = .trip(fallback.id)
            } else {
                clearSelectionOrSelectFirstEnabledProviderSync()
            }
        }
        tripPendingDelete = nil
    }

    private func performPendingTripBatchDeletion(_ policy: TripDeletionBookingPolicy) {
        let ids = pendingDeleteTripIDs
        let tripsByID = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })
        let result = SelectionBatchDeleteHandlers.deleteTrips(ids: ids) { id in
            guard let trip = tripsByID[id] else {
                throw ContentSelectionBatchDeleteError.tripMissing
            }
            try TripDeletion.perform(trip: trip, in: modelContext, bookings: policy)
        }
        recordBatchDeleteEvents(result.events)
        selectedTripIDs = SelectionBatchDeletion.remainingIDs(from: ids, outcome: result.outcome)
        pendingDeleteTripIDs = []

        if case .failed(_, let errorDescription, _) = result.outcome {
            persistErrorMessage = errorDescription
        }
        updateTripSelectionAfterDeletion(excluding: ids.subtracting(selectedTripIDs))
    }

    private func performPendingOpenBookingDeletion() {
        guard let booking = pendingDeleteOpenBooking else { return }
        do {
            try BookingDeletion.perform(booking: booking, in: modelContext)
        } catch {
            persistErrorMessage = error.localizedDescription
        }
        selectedOpenBookingIDs.remove(booking.id)
        pendingDeleteOpenBooking = nil
    }

    private func performPendingOpenBookingBatchDeletion() {
        let ids = pendingDeleteOpenBookingIDs
        let bookingsByID = Dictionary(uniqueKeysWithValues: allBookings.map { ($0.id, $0) })
        let result = SelectionBatchDeleteHandlers.deleteOpenBookings(ids: ids) { id in
            guard let booking = bookingsByID[id] else {
                throw ContentSelectionBatchDeleteError.bookingMissing
            }
            try BookingDeletion.perform(booking: booking, in: modelContext)
        }
        recordBatchDeleteEvents(result.events)
        let liveIDs = Set(
            (selection == .elapsedOpenBookings ? elapsedOpenBookings : openBookings).map(\.id)
        )
        selectedOpenBookingIDs = SelectionBatchDeletion.remainingIDs(from: ids, outcome: result.outcome)
            .intersection(liveIDs)
        pendingDeleteOpenBookingIDs = []

        if case .failed(_, let errorDescription, _) = result.outcome {
            persistErrorMessage = errorDescription
            openSelectionAnchor = selectedOpenBookingIDs.first
            return
        }
        let mailboxBookings = (selection == .elapsedOpenBookings ? elapsedOpenBookings : openBookings)
            .filter { !ids.contains($0.id) }
        selectedOpenBookingIDs = mailboxBookings.first.map { [$0.id] } ?? []
        openSelectionAnchor = selectedOpenBookingIDs.first
    }

    private func recordBatchDeleteEvents(_ events: [DiagnosticEvent]) {
        Task {
            for event in events {
                await DiagnosticLogger.shared.record(event)
            }
        }
    }

    private func updateTripSelectionAfterDeletion(excluding deletedIDs: Set<UUID>) {
        if let primaryID = TripMultiSelectionPrimary.primaryID(
            in: selectedTripIDs,
            anchor: tripSelectionAnchor
        ) {
            selection = .trip(primaryID)
            return
        }
        if let fallback = trips.first(where: { !deletedIDs.contains($0.id) }) {
            selectedTripIDs = [fallback.id]
            tripSelectionAnchor = fallback.id
            selection = .trip(fallback.id)
        } else {
            clearSelectionOrSelectFirstEnabledProviderSync()
        }
    }

    private func requestOpenBookingDeletion(_ booking: SDBooking) {
        pendingDeleteOpenBooking = booking
        showOpenBookingDeleteConfirmation = true
    }

    private func requestOpenBookingBatchDeletion(_ ids: Set<UUID>) {
        guard ids.count > 1 else { return }
        selectedOpenBookingIDs = ids
        pendingDeleteOpenBookingIDs = ids
        showOpenBookingBatchDeleteConfirmation = true
    }

    private func requestTripBatchDeletion(_ ids: Set<UUID>) {
        guard ids.count > 1 else { return }
        selectedTripIDs = ids
        pendingDeleteTripIDs = ids
        showTripBatchDeleteConfirmation = true
    }

    /// Aktuell selektierte Buchung für Portal-Menü/Command (Open + Storno).
    private var selectedPortalBooking: SDBooking? {
        switch selection {
        case .openBookings:
            guard selectedOpenBookingIDs.count == 1,
                  let id = selectedOpenBookingIDs.first else {
                return nil
            }
            return openBookings.first(where: { $0.id == id })
        case .elapsedOpenBookings:
            guard selectedOpenBookingIDs.count == 1,
                  let id = selectedOpenBookingIDs.first else {
                return nil
            }
            return elapsedOpenBookings.first(where: { $0.id == id })
        case .trip(let tripID):
            guard let trip = trips.first(where: { $0.id == tripID }),
                  let timelineID = TimelineSelection.primaryID(in: selectedTimelineIDs),
                  let bookingUUID = UUID(uuidString: timelineID) else {
                return nil
            }
            return trip.resolvedBookings.first(where: { $0.id == bookingUUID })
        default:
            return nil
        }
    }

    private var selectedBookingPortalCommandState: BookingPortalOpenCommandState {
        guard let booking = selectedPortalBooking else {
            return BookingPortalOpenCommandState(linkMode: .none)
        }
        return BookingPortalOpenCommandState(
            booking: booking,
            hasSessionWebView: sessionHub.hasSessionWebView(for: booking)
        )
    }

    @ViewBuilder
    private var mainColumn: some View {
        if !sessionProbeFinished, selection == nil {
            ZStack {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L10n.string(.syncProviderSessionsChecking))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Startup Probe: 1x1 Element direkt in der sichtbaren View-Hierarchie,
                // damit SwiftUI Lifecycle-Tasks zuverlässig feuern.
                ProviderSessionProbeHost(onFinished: handleSessionProbeFinished)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
            }
        } else if case .trip = selection, selectedTripIDs.count > 1 {
            TripMultiSelectionSummary(
                selectedCount: selectedTripIDs.count,
                onDelete: { requestTripBatchDeletion(selectedTripIDs) }
            )
        } else {
            switch selection {
            case .providerSync:
                ProviderSyncContainer(selectedProviderID: providerSyncSelectionBinding)
            case .trip, .openBookings, .elapsedOpenBookings:
                PersistentHorizontalSplitView(
                    leftWidth: $bookingListColumnWidth,
                    leftMinWidth: bookingListMinWidth,
                    rightMinWidth: detailMinWidth
                ) {
                    contentColumn
                } right: {
                    detailContent
                }
            case .trips, .none:
                ContentUnavailableView {
                    Label(L10n.string(.tripWelcome), systemImage: "airplane")
                } description: {
                    Text(
                        enabledProviderIDs.isEmpty
                            ? L10n.string(.syncProviderDisabledHint)
                            : L10n.string(.tripSelectSidebarOrProvider)
                    )
                } actions: {
                    Button(L10n.string(.actionCreateTrip)) {
                        showCreateTrip = true
                    }
                    .accessibilityIdentifier(UITestingIdentifiers.emptyStateNewTrip)
                    if shouldShowProviderSetupReopen {
                        Button(L10n.string(.setupProvidersReopen)) {
                            presentProviderSetupFromReopen()
                        }
                        .accessibilityIdentifier(UITestingIdentifiers.providerSetupReopen)
                    }
                    if enabledProviderIDs.first != nil {
                        Button(L10n.string(.actionOpenSync)) {
                            selectFirstEnabledProviderSyncIfAvailable()
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(UITestingIdentifiers.emptyState)
            }
        }
    }

    @ViewBuilder
    private var globalSyncStatusBar: some View {
        let statusText = store?.statusMessage
        let errorText = store?.errorMessage
        if store?.messageProviderID == nil,
           (statusText?.isEmpty == false || errorText?.isEmpty == false) {
            HStack(alignment: .top, spacing: 8) {
                if store?.isSyncing == true {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let statusText, !statusText.isEmpty {
                        Text(statusText)
                            .font(.callout)
                            .foregroundStyle(errorText != nil ? Color.red : Color.secondary)
                    }
                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.callout)
                            .foregroundStyle(Color.red)
                            .textSelection(.enabled)
                        PublicGitHubIssueReportActions(
                            syncError: errorText,
                            providerID: store?.messageProviderID,
                            store: store
                        )
                    }
                }
                if errorText != nil, let pane = store?.privacySettingPane {
                    OpenPrivacySettingsButton(pane: pane)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }

    private var syncAllSettings: AppSettings {
        AppSettings(
            notificationEnabled: notificationEnabled,
            eventKitEnabled: eventKitEnabled,
            calendarTitle: calendarTitle,
            reminderCalendarTitle: reminderCalendarTitle,
            leadTimesDaysRaw: leadTimesDaysRaw,
            calendarTitleMode: CalendarTitleMode(rawValue: calendarTitleModeRaw) ?? .tripTitle,
            calendarTripTimesEnabled: calendarTripTimesEnabled,
            calendarFlightTimesEnabled: calendarFlightTimesEnabled,
            calendarHotelStaysEnabled: calendarHotelStaysEnabled,
            eventCalendarCreateIfMissing: eventCalendarCreateIfMissing,
            reminderCalendarCreateIfMissing: reminderCalendarCreateIfMissing
        )
    }

    private var registeredProviderIDs: [ProviderID] {
        _ = providerEnableEpoch
        return providerRegistry?.syncProviderIDs ?? []
    }

    private var enabledProviderIDs: [ProviderID] {
        _ = providerEnableEpoch
        return providerRegistry?.enabledSyncProviderIDs() ?? []
    }

    private var syncAllCandidates: [(ProviderID, WKWebView)] {
        guard let sessionHub else { return [] }
        return SyncAllCoordinator.candidates(
            enabledProviderIDs: enabledProviderIDs,
            sessionHub: sessionHub
        )
    }

    @MainActor
    private func runSyncAll() async {
        guard let store, let sessionHub else { return }
        let runID = UUID()
        await SyncAllCoordinator.run(
            syncStore: store,
            enabledProviderIDs: enabledProviderIDs,
            sessionHub: sessionHub,
            settings: syncAllSettings,
            navigationHints: { id in
                NavigationHintURLs.ordered(hubURLString: sessionHub.lastURLString(for: id))
            },
            diagnosticRunID: runID
        )
    }

    private func handleSessionProbeFinished(needingLogin: [ProviderID]) {
        sessionProbeFinished = true
        guard !didApplyInitialSelection else { return }
        didApplyInitialSelection = true

        if let firstLogin = needingLogin.first {
            selection = .providerSync(firstLogin)
        } else if let trip = trips.first {
            selection = .trip(trip.id)
        } else if let firstEnabled = enabledProviderIDs.first {
            selection = .providerSync(firstEnabled)
        } else {
            selection = nil
        }
    }

    /// Binding für Provider-Sync-Auswahl (Sidebar ↔ Login-Queue-Orchestrator).
    private var providerSyncSelectionBinding: Binding<ProviderID> {
        Binding(
            get: {
                if case .providerSync(let id) = selection { return id }
                return enabledProviderIDs.first
                    ?? registeredProviderIDs.first
                    ?? .manual
            },
            set: { selection = .providerSync($0) }
        )
    }

    private func selectFirstEnabledProviderSyncIfAvailable() {
        guard let providerID = enabledProviderIDs.first else { return }
        selection = .providerSync(providerID)
    }

    private func clearSelectionOrSelectFirstEnabledProviderSync() {
        if let providerID = enabledProviderIDs.first {
            selection = .providerSync(providerID)
        } else {
            selection = nil
        }
    }

    private var shouldShowProviderSetupReopen: Bool {
        _ = providerEnableEpoch
        return !AppSettingsDefaults.current.bool(forKey: AppSettingsKeys.providerSetupCompleted)
            && enabledProviderIDs.isEmpty
    }

    private func presentProviderSetupIfNeeded() {
        guard ProviderFirstLaunchSetup.shouldPresent() else { return }
        guard !showProviderSetup else { return }
        showProviderSetup = true
        recordProviderSetupPresentedIfNeeded(reason: "fresh_launch")
    }

    private func presentProviderSetupFromReopen() {
        showProviderSetup = true
        ProviderFirstLaunchSetupDiagnostics.recordPresented(reason: "reopen")
    }

    private func completeProviderSetup(enabledIDs: Set<ProviderID>) {
        guard ProviderFirstLaunchSetup.acceptsContinue(enabledIDs: enabledIDs) else { return }
        let defaults = AppSettingsDefaults.current
        ProviderFirstLaunchSetup.applySelection(enabledIDs: enabledIDs, defaults: defaults)
        ProviderEnabledChange.notify()
        ProviderFirstLaunchSetup.markCompleted(defaults: defaults)
        showProviderSetup = false
        selectFirstEnabledProviderSyncIfAvailable()
        ProviderFirstLaunchSetupDiagnostics.recordCompleted(enabledCount: enabledIDs.count)
    }

    private func deferProviderSetup() {
        ProviderFirstLaunchSetup.markDeferred()
        showProviderSetup = false
        ProviderFirstLaunchSetupDiagnostics.recordDeferred()
    }

    private func recordProviderSetupPresentedIfNeeded(reason: String) {
        guard !didRecordProviderSetupPresented else { return }
        didRecordProviderSetupPresented = true
        ProviderFirstLaunchSetupDiagnostics.recordPresented(reason: reason)
    }

    private var sidebarMailbox: SidebarOpenBookingMailbox? {
        switch selection {
        case .openBookings: return .current
        case .elapsedOpenBookings: return .elapsed
        default: return nil
        }
    }

    private var sidebarProviderID: ProviderID? {
        if case .providerSync(let id) = selection { return id }
        return nil
    }

    private var currentSidebarListIDs: Set<SidebarListItemID> {
        SidebarListSelectionBridge.listIDs(
            providerID: sidebarProviderID,
            mailbox: sidebarMailbox,
            openBookingIDs: selectedOpenBookingIDs,
            selectedTripIDs: selectedTripIDs,
            tripBookingIDs: Set(selectedTimelineIDs.compactMap(UUID.init(uuidString:)))
        )
    }

    private var sidebarListSelection: Binding<Set<SidebarListItemID>> {
        Binding(
            get: { currentSidebarListIDs },
            set: { newValue in
                if newValue.isEmpty { return }
                guard let result = SidebarListSelectionBridge.apply(
                    listIDs: newValue,
                    tripIDForBooking: { bookingID in
                        allBookings.first(where: { $0.id == bookingID })?.trip?.id
                    }
                ) else { return }
                applySidebarListResult(result)
            }
        )
    }

    private var sidebar: some View {
        List(selection: sidebarListSelection) {
            Section(L10n.string(.syncProvider)) {
                ForEach(registeredProviderIDs, id: \.self) { providerID in
                    ProviderSidebarRow(providerID: providerID)
                        .tag(SidebarListItemID.provider(providerID))
                }
            }

            Section {
                if openBookings.isEmpty {
                    Text(L10n.string(.tripNoOpenBookings))
                        .foregroundStyle(.secondary)
                } else {
                    let visibleIDs = SidebarOpenSectionOutline.visibleBookingIDs(
                        from: openBookings.map(\.id),
                        isExpanded: expandedOpenMailbox
                    )
                    ForEach(openBookings.filter { visibleIDs.contains($0.id) }) { booking in
                        sidebarOpenBookingRow(booking: booking, mailboxSelection: .openBookings)
                    }
                }
            } header: {
                sidebarOpenSectionHeader(
                    title: L10n.string(.tripOpenBookings),
                    isExpanded: $expandedOpenMailbox,
                    hasBookings: !openBookings.isEmpty,
                    selectionValue: .openBookings,
                    createTripFromAll: {
                        selection = .openBookings
                        selectedOpenBookingIDs = Set(openBookings.map(\.id))
                        OpenBookingCreateTripAction.assignSeedFromAll(
                            in: allBookings,
                            seed: $tripCreateSeed,
                            showFailed: $showCreateTripFromBookingsFailed
                        )
                    }
                )
            }

            Section {
                if currentTrips.isEmpty {
                    if elapsedTrips.isEmpty {
                        Text(L10n.string(.tripNoTripsYet))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    let gapBadges = SDTrip.listGapBadgeCounts(for: currentTrips)
                    ForEach(currentTrips) { trip in
                        sidebarTripEntry(
                            trip: trip,
                            tripBookings: trip.sidebarChildBookings(tripIsElapsed: false),
                            gapCount: gapBadges[trip.id],
                            tripMenuKind: .trip
                        )
                    }
                }
            } header: {
                HStack {
                    Text(L10n.string(.tripTrips))
                    Spacer()
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(L10n.string(.actionCreateTrip))
                }
            }
            if !elapsedTrips.isEmpty || !elapsedOpenBookings.isEmpty {
                Section {
                    if !elapsedOpenBookings.isEmpty {
                        let visibleIDs = SidebarOpenSectionOutline.visibleBookingIDs(
                            from: elapsedOpenBookings.map(\.id),
                            isExpanded: expandedElapsedOpenMailbox
                        )
                        ForEach(elapsedOpenBookings.filter { visibleIDs.contains($0.id) }) { booking in
                            sidebarOpenBookingRow(booking: booking, mailboxSelection: .elapsedOpenBookings)
                        }
                    }
                    ForEach(elapsedTrips) { trip in
                        sidebarTripEntry(
                            trip: trip,
                            tripBookings: trip.sidebarChildBookings(tripIsElapsed: true),
                            gapCount: nil,
                            tripMenuKind: .elapsedTrip
                        )
                    }
                } header: {
                    sidebarOpenSectionHeader(
                        title: L10n.string(.bookingElapsed),
                        isExpanded: $expandedElapsedOpenMailbox,
                        hasBookings: !elapsedOpenBookings.isEmpty,
                        selectionValue: .elapsedOpenBookings,
                        createTripFromAll: {
                            selection = .elapsedOpenBookings
                            selectedOpenBookingIDs = Set(elapsedOpenBookings.map(\.id))
                            OpenBookingCreateTripAction.assignSeed(
                                fromIDs: Set(elapsedOpenBookings.map(\.id)),
                                in: elapsedOpenBookings,
                                seed: $tripCreateSeed,
                                showFailed: $showCreateTripFromBookingsFailed
                            )
                        }
                    )
                }
            }
        }
        .listStyle(.sidebar)
        // Titelleiste = Produktmarke; Sidebar-Sektion bleibt `trip.trips` („Reisen“ = Trip-Liste).
        .navigationTitle(VoyennaBrand.displayName)
        .accessibilityIdentifier(UITestingIdentifiers.sidebar)
        .contextMenu(forSelectionType: SidebarListItemID.self) { menuIDs in
            sidebarListContextMenu(menuIDs: menuIDs)
        }
    }

    @ViewBuilder
    private func sidebarOpenSectionHeader(
        title: String,
        isExpanded: Binding<Bool>,
        hasBookings: Bool,
        selectionValue: SidebarSelection,
        createTripFromAll: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            if hasBookings {
                Button {
                    isExpanded.wrappedValue.toggle()
                } label: {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpanded.wrappedValue
                    ? L10n.string(.tripCollapseBookings)
                    : L10n.string(.tripExpandBookings))
                .accessibilityLabel(isExpanded.wrappedValue
                    ? L10n.string(.tripCollapseBookings)
                    : L10n.string(.tripExpandBookings))
                .accessibilityIdentifier(UITestingIdentifiers.sidebarExpandBookings)
            }

            if hasBookings {
                Button {
                    selection = selectionValue
                } label: {
                    Text(title)
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
            }
        }
        .contextMenu {
            let bookingCount = selectionValue == .elapsedOpenBookings
                ? elapsedOpenBookings.count
                : openBookings.count
            let actions = SidebarEntryContextActions.actions(for: selectionValue == .elapsedOpenBookings
                ? .elapsedOpenBookingMailbox
                : .openBookingMailbox)
            if actions.contains(.createTripFromAllOpen), bookingCount > 0 {
                Button(action: createTripFromAll) {
                    CreateTripFromAllOpenBookingsLabel(count: bookingCount)
                }
            }
        }
    }

    @ViewBuilder
    private func sidebarOpenBookingRow(
        booking: SDBooking,
        mailboxSelection: SidebarSelection
    ) -> some View {
        let isBookingSelected = selection == mailboxSelection
            && selectedOpenBookingIDs.contains(booking.id)
        VStack(alignment: .leading, spacing: 2) {
            Text(booking.presentationTitle)
                .lineLimit(1)
            Text(BookingScheduleRangeText.make(for: booking))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if BookingOverlapCaption.isVisible(partnerTitles: overlapPartnerTitles(for: booking.id)) {
                BookingOverlapCaption(partnerTitles: overlapPartnerTitles(for: booking.id))
            }
        }
        .padding(.leading, 28)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isBookingSelected
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityIdentifier(UITestingIdentifiers.bookingRow(booking.id))
        .accessibilityAddTraits(isBookingSelected ? [.isSelected] : [])
        .tag(
            mailboxSelection == .elapsedOpenBookings
                ? SidebarListItemID.elapsedBooking(booking.id)
                : SidebarListItemID.openBooking(booking.id)
        )
    }

    @ViewBuilder
    private func openBookingContextMenuItems(
        for booking: SDBooking,
        effectiveIDs: Set<UUID>,
        in mailboxBookings: [SDBooking],
        kind: SidebarEntryKind
    ) -> some View {
        let actions = SidebarEntryContextActions.actions(
            for: kind,
            selectionCount: effectiveIDs.count
        )
        if effectiveIDs.count == 1 {
            BookingCopyConfirmationMenuItems(booking: booking)
            if let url = booking.browserURL {
                BookingPortalOpenButton(browserURL: url)
                CopyLinkMenuItem(url: url)
            }
            BookingPortalCancelMenuItems(
                booking: booking,
                hasSessionWebView: sessionHub.hasSessionWebView(for: booking),
                onPresentCancel: { presentation, url in
                    BookingPortalCancelRequest.route(
                        presentation,
                        url: url,
                        booking: booking,
                        openURL: { openURL($0) },
                        setCancelRequest: { cancelRequest = $0 }
                    )
                }
            )
            if actions.contains(.assignToTrip), let trip = matchingTrip(for: booking) {
                Button(L10n.string(.actionAssignToTrip)) {
                    applyAfterTripFocus(trip: trip) {
                        NotificationCenter.default.post(
                            name: .reisenAssignBookings,
                            object: booking.id
                        )
                    }
                }
            }
        }
        if actions.contains(.createTripFromSelection) {
            Button {
                OpenBookingCreateTripAction.assignSeed(
                    fromIDs: effectiveIDs,
                    in: mailboxBookings,
                    seed: $tripCreateSeed,
                    showFailed: $showCreateTripFromBookingsFailed
                )
            } label: {
                CreateTripFromBookingsLabel()
            }
        }
        if actions.contains(.deleteBooking) {
            Divider()
            Button(role: .destructive) {
                if effectiveIDs.count > 1 {
                    requestOpenBookingBatchDeletion(effectiveIDs)
                } else {
                    requestOpenBookingDeletion(booking)
                }
            } label: {
                Text(L10n.string(.actionDeleteEllipsis))
            }
            .accessibilityIdentifier(UITestingIdentifiers.deleteBookingMenu)
        }
    }

    @ViewBuilder
    private func sidebarTripEntry(
        trip: SDTrip,
        tripBookings: [SDBooking],
        gapCount: Int?,
        tripMenuKind _: SidebarEntryKind
    ) -> some View {
        let isExpanded = expandedTripIDs.contains(trip.id)
        let isTripSelected = selectedTripIDs.contains(trip.id)
        // Sibling List-Rows (nicht nested VStack): sonst kein macOS-Kontextmenü auf Kindern.
        HStack(spacing: 4) {
            if !tripBookings.isEmpty {
                Button {
                    expandedBinding(for: trip.id).wrappedValue.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpanded
                    ? L10n.string(.tripCollapseBookings)
                    : L10n.string(.tripExpandBookings))
                .accessibilityLabel(isExpanded
                    ? L10n.string(.tripCollapseBookings)
                    : L10n.string(.tripExpandBookings))
                .accessibilityIdentifier(UITestingIdentifiers.sidebarExpandBookings)
            }

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.title)
                    Text(dateRange(trip))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let meta = L10n.tripCompletenessListMeta(
                        futureBookingCount: tripBookings.count,
                        gapCount: gapCount
                    ) {
                        Text(meta)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "airplane")
            }
            .contentShape(Rectangle())
            .accessibilityIdentifier(UITestingIdentifiers.tripRow(trip.id))
        }
        .background(
            isTripSelected
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityAddTraits(isTripSelected ? [.isSelected] : [])
        .tag(SidebarListItemID.trip(trip.id))

        if isExpanded {
            if case .create = bookingEditorSession, selection == .trip(trip.id) {
                BookingCreateDraftSidebarRow(
                    title: BookingCreateDraftSelection.displayTitle(typedTitle: createDraftTypedTitle),
                    isSelected: BookingCreateDraftSelection.isCreateDraftSelection(selectedTimelineIDs)
                ) {
                    selectedTimelineIDs = [BookingCreateDraftSelection.timelineID]
                }
            }
            ForEach(tripBookings) { booking in
                sidebarTripBookingRow(booking: booking, trip: trip)
            }
        }
    }

    @ViewBuilder
    private func sidebarTripBookingRow(booking: SDBooking, trip: SDTrip) -> some View {
        let bookingID = booking.id.uuidString
        let isBookingSelected = selection == .trip(trip.id)
            && selectedTimelineIDs.contains(bookingID)
        VStack(alignment: .leading, spacing: 2) {
            Text(booking.presentationTitle)
                .lineLimit(1)
            Text(BookingScheduleRangeText.make(for: booking))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if BookingOverlapCaption.isVisible(partnerTitles: overlapPartnerTitles(for: booking.id)) {
                BookingOverlapCaption(partnerTitles: overlapPartnerTitles(for: booking.id))
            }
        }
        .padding(.leading, 28)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isBookingSelected
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityIdentifier(UITestingIdentifiers.bookingRow(booking.id))
        .accessibilityAddTraits(isBookingSelected ? [.isSelected] : [])
        .tag(SidebarListItemID.tripBooking(booking.id))
    }

    private func applyUITestingLaunchSelectionIfNeeded() {
        guard UITestingLaunch.isActive, !didApplyInitialSelection else { return }
        didApplyInitialSelection = true
        sessionProbeFinished = true
        guard UITestingLaunch.shouldSeed else { return }
        if let trip = trips.first(where: { $0.id == UITestingSeed.tripID }) ?? trips.first {
            selection = .trip(trip.id)
            selectedTripIDs = [trip.id]
            tripSelectionAnchor = trip.id
        }
    }

    private var openBookings: [SDBooking] {
        OpenBookingMatching.currentUnassigned(in: allBookings)
    }

    private var elapsedOpenBookings: [SDBooking] {
        OpenBookingMatching.elapsedUnassigned(in: allBookings)
    }

    private var overlapPartnerIDsByBookingID: [UUID: [UUID]] {
        BookingDayOverlap.partnerIDsByID(sdBookings: allBookings)
    }

    private var bookingPresentationTitleByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: allBookings.map { ($0.id, $0.presentationTitle) })
    }

    private func overlapPartnerTitles(for bookingID: UUID) -> [String] {
        BookingOverlapCaption.partnerTitles(
            for: bookingID,
            partnerIDsByBookingID: overlapPartnerIDsByBookingID,
            titleByID: bookingPresentationTitleByID
        )
    }

    private var currentTrips: [SDTrip] {
        trips.filter { !$0.isElapsed() }
    }

    private var elapsedTrips: [SDTrip] {
        trips.filter { $0.isElapsed() }
    }

    private var selectedOpenBookings: [SDBooking] {
        openBookings.filter { selectedOpenBookingIDs.contains($0.id) }
    }

    private func matchingTrip(for booking: SDBooking) -> SDTrip? {
        trips.first { OpenBookingMatching.isCandidate(booking, for: $0) }
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch selection {
        case .trip(let id):
            if let trip = trips.first(where: { $0.id == id }) {
                TripDetailView(
                    mode: .list,
                    trip: trip,
                    selectedTimelineIDs: $selectedTimelineIDs,
                    gapEditorPayload: $gapEditorPayload,
                    bookingEditorSession: $bookingEditorSession,
                    createDraftTypedTitle: $createDraftTypedTitle
                )
                .onReceive(NotificationCenter.default.publisher(for: .reisenAddBooking)) { _ in
                    startCreateBooking(in: trip)
                }
                .id(id)
            } else {
                ContentUnavailableView(
                    L10n.string(.tripTripMissing),
                    systemImage: "exclamationmark.triangle",
                    description: Text(L10n.string(.tripTripMissingDescription))
                )
            }
        case .providerSync(let providerID):
            ProviderSyncContainer(selectedProviderID: providerSyncSelectionBinding)
                .id(providerID)
        case .openBookings:
            if openBookings.isEmpty {
                ContentUnavailableView {
                    Label(L10n.string(.tripNoOpenBookings), systemImage: "calendar")
                } description: {
                    Text(L10n.string(.tripNoOpenBookingsCurrent))
                } actions: {
                    if enabledProviderIDs.first != nil {
                        Button(L10n.string(.actionOpenSync)) {
                            selectFirstEnabledProviderSyncIfAvailable()
                        }
                    }
                }
            } else {
                let partition = OpenBookingMatching.partitionByFillOpportunity(
                    bookings: openBookings,
                    trips: trips
                )
                List(selection: $selectedOpenBookingIDs) {
                    OpenBookingsFillSections(partition: partition) { booking, fillCaption in
                        OpenBookingRow(
                            booking: booking,
                            fillCaption: fillCaption,
                            partnerTitles: overlapPartnerTitles(for: booking.id)
                        )
                            .tag(booking.id)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier(
                                UITestingIdentifiers.contentOpenBookingRow(booking.id)
                            )
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .accessibilityIdentifier(UITestingIdentifiers.openBookingsContent)
                .navigationTitle(L10n.string(.tripOpenBookings))
                .contextMenu(forSelectionType: UUID.self) { menuIDs in
                    let selectedIDs = MenuEffectiveSelection.resolve(
                        menu: menuIDs,
                        bound: selectedOpenBookingIDs
                    )
                    if selectedIDs.count == 1,
                       let bookingID = selectedIDs.first,
                       let booking = openBookings.first(where: { $0.id == bookingID }) {
                        openBookingContextMenuItems(
                            for: booking,
                            effectiveIDs: selectedIDs,
                            in: openBookings,
                            kind: .openBooking
                        )
                    } else if !selectedIDs.isEmpty {
                        Button {
                            OpenBookingCreateTripAction.assignSeed(
                                fromIDs: selectedIDs,
                                in: openBookings,
                                seed: $tripCreateSeed,
                                showFailed: $showCreateTripFromBookingsFailed
                            )
                        } label: {
                            CreateTripFromBookingsLabel()
                        }
                        Button(L10n.string(.actionDeleteEllipsis), role: .destructive) {
                            requestOpenBookingBatchDeletion(selectedIDs)
                        }
                    }
                }
                .onAppear {
                    if selectedOpenBookingIDs.isEmpty, let first = openBookings.first?.id {
                        selectedOpenBookingIDs = [first]
                    }
                }
                .onChange(of: openBookings.count) { _, _ in
                    selectedOpenBookingIDs = selectedOpenBookingIDs.filter { id in
                        openBookings.contains(where: { $0.id == id })
                    }
                    if selectedOpenBookingIDs.isEmpty, let first = openBookings.first?.id {
                        selectedOpenBookingIDs = [first]
                    }
                }
            }
        case .elapsedOpenBookings:
            if elapsedOpenBookings.isEmpty {
                ContentUnavailableView {
                    Label(L10n.string(.tripNoOpenBookings), systemImage: "calendar")
                } description: {
                    Text(L10n.string(.bookingElapsed))
                }
            } else {
                List(selection: $selectedOpenBookingIDs) {
                    ForEach(elapsedOpenBookings) { booking in
                        OpenBookingRow(
                            booking: booking,
                            fillCaption: nil,
                            partnerTitles: overlapPartnerTitles(for: booking.id)
                        )
                            .tag(booking.id)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier(
                                UITestingIdentifiers.contentOpenBookingRow(booking.id)
                            )
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .navigationTitle(L10n.string(.bookingElapsed))
                .contextMenu(forSelectionType: UUID.self) { menuIDs in
                    let selectedIDs = MenuEffectiveSelection.resolve(
                        menu: menuIDs,
                        bound: selectedOpenBookingIDs
                    )
                    if selectedIDs.count == 1,
                       let bookingID = selectedIDs.first,
                       let booking = elapsedOpenBookings.first(where: { $0.id == bookingID }) {
                        openBookingContextMenuItems(
                            for: booking,
                            effectiveIDs: selectedIDs,
                            in: elapsedOpenBookings,
                            kind: .elapsedOpenBooking
                        )
                    } else if !selectedIDs.isEmpty {
                        Button {
                            OpenBookingCreateTripAction.assignSeed(
                                fromIDs: selectedIDs,
                                in: elapsedOpenBookings,
                                seed: $tripCreateSeed,
                                showFailed: $showCreateTripFromBookingsFailed
                            )
                        } label: {
                            CreateTripFromBookingsLabel()
                        }
                        Button(L10n.string(.actionDeleteEllipsis), role: .destructive) {
                            requestOpenBookingBatchDeletion(selectedIDs)
                        }
                    }
                }
                .onAppear {
                    if selectedOpenBookingIDs.isEmpty, let first = elapsedOpenBookings.first?.id {
                        selectedOpenBookingIDs = [first]
                    }
                }
            }
        case .none, .trips:
            ContentUnavailableView(
                L10n.string(.tripSelectTrip),
                systemImage: "airplane",
                description: Text(L10n.string(.tripSelectSidebar))
            )
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .providerSync:
            // Detailspalte ist für Browser/Provider-Sync ausgeblendet; hier nur ein Platzhalter.
            EmptyView()
                .frame(width: 0)
                .clipped()
        case .none:
            EmptyView()
        case .trips:
            ContentUnavailableView(
                L10n.string(.tripTrips),
                systemImage: "airplane",
                description: Text(L10n.string(.tripSelectTripOrSync))
            )
        case .openBookings:
            if selectedOpenBookingIDs.count > 1 {
                ScrollView {
                    OpenBookingMultiSelectionSummary(
                        selected: selectedOpenBookings,
                        onCreateTrip: {
                            OpenBookingCreateTripAction.assignSeed(
                                fromIDs: selectedOpenBookingIDs,
                                in: openBookings,
                                seed: $tripCreateSeed,
                                showFailed: $showCreateTripFromBookingsFailed
                            )
                        },
                        onDelete: { requestOpenBookingBatchDeletion(selectedOpenBookingIDs) }
                    )
                    .padding(16)
                }
                .navigationTitle(L10n.string(.tripOpenBookings))
            } else if let bookingID = selectedOpenBookingIDs.first,
                      let booking = openBookings.first(where: { $0.id == bookingID }) {
                OpenBookingDetailView(
                    booking: booking,
                    matchingTrip: matchingTrip(for: booking),
                    partnerTitles: overlapPartnerTitles(for: booking.id),
                    onCreateTrip: {
                        OpenBookingCreateTripAction.assignSeed(
                            fromIDs: [booking.id],
                            in: openBookings,
                            seed: $tripCreateSeed,
                            showFailed: $showCreateTripFromBookingsFailed
                        )
                    }
                )
                .id(booking.id)
                .navigationTitle(booking.presentationTitle)
            } else if let first = openBookings.first {
                OpenBookingDetailView(
                    booking: first,
                    matchingTrip: matchingTrip(for: first),
                    partnerTitles: overlapPartnerTitles(for: first.id),
                    onCreateTrip: {
                        OpenBookingCreateTripAction.assignSeed(
                            fromIDs: [first.id],
                            in: openBookings,
                            seed: $tripCreateSeed,
                            showFailed: $showCreateTripFromBookingsFailed
                        )
                    }
                )
                .id(first.id)
                .navigationTitle(first.presentationTitle)
            } else {
                ContentUnavailableView(
                    L10n.string(.tripNoOpenBookings),
                    systemImage: "calendar",
                    description: Text(L10n.string(.tripNoOpenBookingsCurrent))
                )
            }
        case .elapsedOpenBookings:
            if selectedOpenBookingIDs.count > 1 {
                ScrollView {
                    OpenBookingMultiSelectionSummary(
                        selected: elapsedOpenBookings.filter {
                            selectedOpenBookingIDs.contains($0.id)
                        },
                        onCreateTrip: {
                            OpenBookingCreateTripAction.assignSeed(
                                fromIDs: selectedOpenBookingIDs,
                                in: elapsedOpenBookings,
                                seed: $tripCreateSeed,
                                showFailed: $showCreateTripFromBookingsFailed
                            )
                        },
                        onDelete: { requestOpenBookingBatchDeletion(selectedOpenBookingIDs) }
                    )
                    .padding(16)
                }
                .navigationTitle(L10n.string(.bookingElapsed))
            } else if let bookingID = selectedOpenBookingIDs.first,
               let booking = elapsedOpenBookings.first(where: { $0.id == bookingID }) {
                OpenBookingDetailView(
                    booking: booking,
                    matchingTrip: matchingTrip(for: booking),
                    partnerTitles: overlapPartnerTitles(for: booking.id),
                    onCreateTrip: {
                        OpenBookingCreateTripAction.assignSeed(
                            fromIDs: [booking.id],
                            in: elapsedOpenBookings,
                            seed: $tripCreateSeed,
                            showFailed: $showCreateTripFromBookingsFailed
                        )
                    }
                )
                .id(booking.id)
                .navigationTitle(booking.presentationTitle)
            } else if let first = elapsedOpenBookings.first {
                OpenBookingDetailView(
                    booking: first,
                    matchingTrip: matchingTrip(for: first),
                    partnerTitles: overlapPartnerTitles(for: first.id),
                    onCreateTrip: {
                        OpenBookingCreateTripAction.assignSeed(
                            fromIDs: [first.id],
                            in: elapsedOpenBookings,
                            seed: $tripCreateSeed,
                            showFailed: $showCreateTripFromBookingsFailed
                        )
                    }
                )
                .id(first.id)
                .navigationTitle(first.presentationTitle)
            } else {
                ContentUnavailableView(
                    L10n.string(.tripNoOpenBookings),
                    systemImage: "calendar",
                    description: Text(L10n.string(.bookingElapsed))
                )
            }
        case .trip(let id):
            if let trip = trips.first(where: { $0.id == id }) {
                TripDetailView(
                    mode: .detail,
                    trip: trip,
                    selectedTimelineIDs: $selectedTimelineIDs,
                    gapEditorPayload: $gapEditorPayload,
                    bookingEditorSession: $bookingEditorSession,
                    createDraftTypedTitle: $createDraftTypedTitle
                )
                .id(id)
            } else {
                ContentUnavailableView(
                    L10n.string(.tripTripMissing),
                    systemImage: "exclamationmark.triangle",
                    description: Text(L10n.string(.tripTripMissingDescription))
                )
            }
        }
    }

    private struct OpenBookingDetailView: View {
        let booking: SDBooking
        let matchingTrip: SDTrip?
        let partnerTitles: [String]
        var onCreateTrip: () -> Void

        @Environment(\.modelContext) private var modelContext
        @Environment(\.providerSessionHub) private var sessionHub
        @Environment(\.openURL) private var openURL
        @State private var cancelRequest: BookingPortalCancelRequest?
        @State private var assignErrorMessage: String?
        @State private var showAssignError = false
        @State private var persistErrorMessage: String?
        @State private var isEditing = false
        @State private var bookingEditorDraft: BookingEditorDraft?
        @State private var pendingDeleteBookingID: UUID?
        @State private var showDeleteConfirmation = false

        private var draftBinding: Binding<BookingEditorDraft>? {
            guard bookingEditorDraft != nil else { return nil }
            return Binding(
                get: { bookingEditorDraft! },
                set: { bookingEditorDraft = $0 }
            )
        }

        private var lastSyncedBarHeight: CGFloat { BookingLastSyncedBar.barHeight }

        var body: some View {
            Group {
                if isEditing, let draftBinding {
                    BookingEditorForm(
                        title: L10n.string(.editorEditTitle),
                        showsSyncOverwriteHint: ProviderID.syncProviderIDs.contains(booking.provider),
                        draft: draftBinding,
                        providerReadOnly: ProviderID.syncProviderIDs.contains(booking.provider),
                        onCancel: {
                            isEditing = false
                            bookingEditorDraft = nil
                        },
                        onSave: {
                            guard let draft = bookingEditorDraft else { return }
                            try draft.apply(to: booking, in: modelContext)
                            isEditing = false
                            bookingEditorDraft = nil
                        }
                    )
                } else {
                    openBookingDetailScroll
                }
            }
            .alert(L10n.string(.tripAssignFailed), isPresented: $showAssignError) {
                Button(L10n.string(.commonOk), role: .cancel) {}
            } message: {
                if let assignErrorMessage, !assignErrorMessage.isEmpty {
                    Text(assignErrorMessage)
                }
            }
            .persistFailureAlert(message: $persistErrorMessage)
            .bookingPortalCancelSheet($cancelRequest)
            .bookingDeleteConfirmAlert(
                isPresented: $showDeleteConfirmation,
                bookingTitle: booking.presentationTitle,
                showsSyncRestoreWarning: ProviderID.syncProviderIDs.contains(booking.provider),
                onConfirm: deletePendingBooking,
                onCancel: { pendingDeleteBookingID = nil }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(UITestingIdentifiers.inspector)
            .onChange(of: booking.id) { _, _ in
                isEditing = false
                bookingEditorDraft = nil
                pendingDeleteBookingID = nil
            }
        }

        private var openBookingDetailScroll: some View {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            BookingDetailContent(
                                booking: booking,
                                partnerTitles: partnerTitles,
                                onEditBooking: {
                                    isEditing = true
                                    bookingEditorDraft = BookingEditorDraft.fromExisting(booking)
                                },
                                onRequestDeleteBooking: { bookingID in
                                    pendingDeleteBookingID = bookingID
                                    showDeleteConfirmation = true
                                },
                                hasSessionWebView: sessionHub.hasSessionWebView(for: booking),
                                onPresentCancel: { presentation, url in
                                    BookingPortalCancelRequest.route(
                                        presentation,
                                        url: url,
                                        booking: booking,
                                        openURL: { openURL($0) },
                                        setCancelRequest: { cancelRequest = $0 }
                                    )
                                }
                            )

                            openBookingAssignmentSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .padding(.bottom, booking.lastSyncedAt == nil ? 0 : lastSyncedBarHeight)

                if let synced = booking.lastSyncedAt {
                    BookingLastSyncedBar(synced: synced)
                        .frame(height: lastSyncedBarHeight)
                }
            }
        }

        private func deletePendingBooking() {
            guard let bookingID = pendingDeleteBookingID else { return }
            guard booking.id == bookingID else { return }
            do {
                try BookingDeletion.perform(booking: booking, in: modelContext)
            } catch {
                persistErrorMessage = error.localizedDescription
            }
            pendingDeleteBookingID = nil
        }

        @ViewBuilder
        private var openBookingAssignmentSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string(.tripAssign))
                    .font(.subheadline.weight(.semibold))

                if let matchingTrip {
                    Button(L10n.string(.actionAssignToTrip)) {
                        do {
                            booking.trip = matchingTrip
                            try modelContext.save()
                        } catch {
                            assignErrorMessage = error.localizedDescription
                            showAssignError = true
                        }
                    }
                    .buttonStyle(.link)
                    .help(L10n.string(.tripAssignOpenBookingHelp))
                } else {
                    Button(action: onCreateTrip) {
                        CreateTripFromBookingsLabel()
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private func dateRange(_ trip: SDTrip) -> String {
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }

    private func focusTrip(_ trip: SDTrip) {
        selection = .trip(trip.id)
        selectedTripIDs = [trip.id]
        tripSelectionAnchor = trip.id
        expandedTripIDs.insert(trip.id)
    }

    private func applySidebarListResult(_ result: SidebarListApplyResult) {
        if let providerID = result.providerID {
            selection = .providerSync(providerID)
            return
        }
        if let mailbox = result.mailbox {
            selection = mailbox == .elapsed ? .elapsedOpenBookings : .openBookings
            selectedOpenBookingIDs = result.openBookingIDs
            if let anchor = result.openBookingIDs.min(by: { $0.uuidString < $1.uuidString }) {
                openSelectionAnchor = anchor
            }
            return
        }
        if !result.tripBookingIDs.isEmpty, let tripID = result.focusedTripID {
            let tripChanged = selection?.tripID != tripID
            selectedTripIDs = [tripID]
            tripSelectionAnchor = tripID
            selection = .trip(tripID)
            let timelineIDs = Set(result.tripBookingIDs.map(\.uuidString))
            let timelineAnchor = result.tripBookingIDs
                .map(\.uuidString)
                .min()
            if tripChanged {
                Task { @MainActor in
                    await Task.yield()
                    selectedTimelineIDs = timelineIDs
                    timelineSelectionAnchor = timelineAnchor
                }
            } else {
                selectedTimelineIDs = timelineIDs
                timelineSelectionAnchor = timelineAnchor
            }
            return
        }
        if !result.tripIDs.isEmpty {
            selectedTripIDs = result.tripIDs
            selectedTimelineIDs = []
            timelineSelectionAnchor = nil
            if let primaryID = TripMultiSelectionPrimary.primaryID(
                in: result.tripIDs,
                anchor: tripSelectionAnchor
            ) {
                selection = .trip(primaryID)
                if tripSelectionAnchor.map(result.tripIDs.contains) != true {
                    tripSelectionAnchor = primaryID
                }
            }
        }
    }

    @ViewBuilder
    private func sidebarListContextMenu(menuIDs: Set<SidebarListItemID>) -> some View {
        let effective = MenuEffectiveSelection.resolve(
            menu: menuIDs,
            bound: currentSidebarListIDs
        )
        switch SidebarListSelectionBridge.menuKind(for: effective) {
        case .openBookings:
            sidebarOpenBookingsMenu(ids: Set(effective.compactMap(\.bookingUUID)), mailbox: .openBookings)
        case .elapsedBookings:
            sidebarOpenBookingsMenu(ids: Set(effective.compactMap(\.bookingUUID)), mailbox: .elapsedOpenBookings)
        case .tripBookings:
            sidebarTripBookingsMenu(ids: Set(effective.compactMap(\.bookingUUID)))
        case .trips:
            sidebarTripsMenu(ids: Set(effective.compactMap(\.tripUUID)))
        case .empty, .mixed, .provider:
            EmptyView()
        }
    }

    @ViewBuilder
    private func sidebarOpenBookingsMenu(ids: Set<UUID>, mailbox: SidebarSelection) -> some View {
        let mailboxBookings = mailbox == .elapsedOpenBookings ? elapsedOpenBookings : openBookings
        let kind: SidebarEntryKind = mailbox == .elapsedOpenBookings ? .elapsedOpenBooking : .openBooking
        if let booking = mailboxBookings.first(where: { ids.contains($0.id) }) {
            openBookingContextMenuItems(
                for: booking,
                effectiveIDs: ids,
                in: mailboxBookings,
                kind: kind
            )
        }
    }

    @ViewBuilder
    private func sidebarTripBookingsMenu(ids: Set<UUID>) -> some View {
        let stringIDs = Set(ids.map(\.uuidString))
        if let bookingID = ids.min(by: { $0.uuidString < $1.uuidString }),
           let booking = allBookings.first(where: { $0.id == bookingID }),
           let trip = booking.trip {
        let actions = SidebarEntryContextActions.actions(
            for: .tripBooking,
            selectionCount: stringIDs.count
        )
        if actions.contains(.edit), stringIDs.count == 1 {
            Button(L10n.string(.commonEdit)) {
                editBooking(booking, in: trip)
            }
        }
        if actions.contains(.addBooking), stringIDs.count == 1 {
            Button(L10n.string(.actionAddBooking)) {
                startCreateBooking(in: trip)
            }
        }
        if stringIDs.count == 1 {
            BookingCopyConfirmationMenuItems(booking: booking)
            if let url = booking.browserURL {
                BookingPortalOpenButton(browserURL: url)
                CopyLinkMenuItem(url: url)
            }
            BookingPortalCancelMenuItems(
                booking: booking,
                hasSessionWebView: sessionHub.hasSessionWebView(for: booking),
                onPresentCancel: { presentation, url in
                    BookingPortalCancelRequest.route(
                        presentation,
                        url: url,
                        booking: booking,
                        openURL: { openURL($0) },
                        setCancelRequest: { cancelRequest = $0 }
                    )
                }
            )
        }
        if actions.contains(.removeFromTrip) || actions.contains(.deleteBooking) {
            Divider()
        }
        if actions.contains(.removeFromTrip) {
            Button(role: .destructive) {
                applyAfterTripFocus(trip: trip) {
                    selectedTimelineIDs = stringIDs
                    NotificationCenter.default.post(
                        name: .reisenRequestRemoveBookingFromTrip,
                        object: Array(ids)
                    )
                }
            } label: {
                Text(L10n.string(.actionRemoveFromTrip))
            }
        }
        if actions.contains(.deleteBooking) {
            Button(role: .destructive) {
                applyAfterTripFocus(trip: trip) {
                    selectedTimelineIDs = stringIDs
                    NotificationCenter.default.post(
                        name: .reisenRequestDeleteBooking,
                        object: Array(ids)
                    )
                }
            } label: {
                Text(L10n.string(.actionDeleteEllipsis))
            }
            .accessibilityIdentifier(UITestingIdentifiers.deleteBookingMenu)
        }
        }
    }

    @ViewBuilder
    private func sidebarTripsMenu(ids: Set<UUID>) -> some View {
        if let tripID = ids.min(by: { $0.uuidString < $1.uuidString }),
           let trip = trips.first(where: { $0.id == tripID }) {
        let kind: SidebarEntryKind = elapsedTrips.contains(where: { $0.id == tripID })
            ? .elapsedTrip
            : .trip
        let actions = SidebarEntryContextActions.actions(for: kind, selectionCount: ids.count)
        if actions.contains(.edit) {
            Button(L10n.string(.commonEdit)) {
                tripToEdit = trip
            }
        }
        if actions.contains(.addBooking) {
            Button(L10n.string(.actionAddBooking)) {
                startCreateBooking(in: trip)
            }
        }
        if actions.contains(.deleteTrip) {
            Divider()
            Button(role: .destructive) {
                if ids.count > 1 {
                    requestTripBatchDeletion(ids)
                } else {
                    tripPendingDelete = trip
                    showTripDeleteConfirmation = true
                }
            } label: {
                Text(L10n.string(.actionDeleteTrip))
            }
            .accessibilityIdentifier(UITestingIdentifiers.deleteTripMenu)
        }
        }
    }

    private func handleSelectionChange(
        from oldSelection: SidebarSelection?,
        to newSelection: SidebarSelection?
    ) {
        let switchedOpenMailbox =
            (oldSelection == .openBookings && newSelection == .elapsedOpenBookings)
            || (oldSelection == .elapsedOpenBookings && newSelection == .openBookings)
        if switchedOpenMailbox {
            let destination = newSelection == .elapsedOpenBookings
                ? elapsedOpenBookings
                : openBookings
            selectedOpenBookingIDs = OpenBookingMailboxSelectionFilter.filter(
                selected: selectedOpenBookingIDs,
                availableInDestination: Set(destination.map(\.id)),
                fallbackFirst: destination.first?.id
            )
            openSelectionAnchor = selectedOpenBookingIDs.first
        }

        switch newSelection {
        case .openBookings, .elapsedOpenBookings:
            selectedTripIDs = []
            tripSelectionAnchor = nil
            selectedTimelineIDs = []
            timelineSelectionAnchor = nil
        case .trip(let id):
            selectedOpenBookingIDs = []
            openSelectionAnchor = nil
            if !selectedTripIDs.contains(id) {
                selectedTripIDs = [id]
                tripSelectionAnchor = id
            }
        case .none, .providerSync, .trips:
            selectedTripIDs = []
            tripSelectionAnchor = nil
        }
    }

    /// Nach Reisewechsel setzt `onChange(selection)` Timeline/Editor zurück — Aktionen danach anwenden.
    private func applyAfterTripFocus(trip: SDTrip, _ action: @MainActor @escaping () -> Void) {
        let tripChanged = selection?.tripID != trip.id
        focusTrip(trip)
        if tripChanged {
            Task { @MainActor in
                await Task.yield()
                action()
            }
        } else {
            action()
        }
    }

    private func editBooking(_ booking: SDBooking, in trip: SDTrip) {
        applyAfterTripFocus(trip: trip) {
            selectedTimelineIDs = [booking.id.uuidString]
            bookingEditorSession = .edit(bookingID: booking.id)
        }
    }

    private var existingDomainBookings: [Booking] {
        allBookings.map(DomainMapper.booking(from:))
    }

    /// Einstieg des Paste-Imports beim Auslösen — die Auswahl darf danach wechseln.
    private var pasteImportEntry: PasteImportEntry {
        selection?.pasteImportEntry ?? .open
    }

    /// Reise des laufenden Imports, eingefroren beim Einstieg (`PasteImportSession.tripID`).
    private var pasteImportTrip: SDTrip? {
        guard let tripID = pasteImport.tripID else { return nil }
        return trips.first { $0.id == tripID }
    }

    private func startPasteImportFromFile() async {
        let entry = pasteImportEntry
        let existing = existingDomainBookings
        do {
            guard let source = try await PasteImportMacSource.fromOpenPanel() else { return }
            pasteImport.start(
                source: source,
                entry: entry,
                existing: existing
            )
        } catch {
            pasteImport.fail(L10n.string(.pasteImportErrorSource))
        }
    }

    private func consumeExternalFiles() {
        beginPasteImportDrop(
            PasteImportDropStartResolver.consumeInbox(isSessionActive: pasteImport.isActive)
        )
    }

    /// Ein Drop bzw. „Öffnen mit“ startet denselben Lauf wie der Dateidialog; das erste gültige File zählt.
    private func startPasteImport(fromDropped urls: [URL]) {
        beginPasteImportDrop(
            PasteImportDropStartResolver.resolve(
                urls: urls,
                isSessionActive: pasteImport.isActive
            )
        )
    }

    private func beginPasteImportDrop(_ start: PasteImportDropStart) {
        if case .ignore = start { return }
        let entry = pasteImportEntry
        let existing = existingDomainBookings
        start.apply(
            onFail: pasteImport.fail,
            onSource: { source in
                pasteImport.start(
                    source: source,
                    entry: entry,
                    existing: existing
                )
            }
        )
    }

    /// Nächster Kandidat aus der Warteschlange in den passenden Editor.
    ///
    /// Erst nach dem laufenden Update-Zyklus, sonst verschluckt ein noch schließendes Sheet
    /// (Kandidatenliste, Fehlerdialog) die neue Präsentation.
    private func advancePasteImportQueue() {
        pasteImportReviewQueue.advance(ifPending: pasteImport.hasPendingCandidates) {
            presentNextPasteImportCandidate()
        }
        if !pasteImport.hasPendingCandidates {
            pasteImport.endReview()
        }
    }

    private func presentNextPasteImportCandidate() {
        guard let candidate = pasteImport.nextCandidate() else {
            pasteImport.endReview()
            return
        }
        let remaining = pasteImport.hasPendingCandidates
        // index/total: grob — Warteschlange ohne feste Gesamtzahl; 1 von n nur wenn noch mehr warten.
        let total = remaining ? 2 : 1
        let index = 1
        if let match = candidate.uniqueMatchedBooking {
            reviewPasteImportEnrich(candidate, match: match, index: index, total: total)
        } else {
            reviewPasteImportNew(candidate, index: index, total: total)
        }
    }

    /// Ergänzen und Neu: eigenes Fenster, Persistenz erst bei Sichern.
    private func reviewPasteImportEnrich(
        _ candidate: PasteImportCandidate,
        match: Booking,
        index: Int,
        total: Int
    ) {
        guard let booking = allBookings.first(where: { $0.id == match.id }) else {
            pasteImport.fail(L10n.string(.pasteImportErrorMatchMissing))
            return
        }
        openPasteImportReview(
            .enriching(candidate: candidate, booking: booking, index: index, total: total)
        )
    }

    private func reviewPasteImportNew(
        _ candidate: PasteImportCandidate,
        index: Int,
        total: Int
    ) {
        openPasteImportReview(
            .creating(
                candidate: candidate,
                tripID: pasteImport.tripID,
                tripStart: pasteImportTrip?.startDate,
                tripEnd: pasteImportTrip?.endDate,
                index: index,
                total: total
            )
        )
    }

    private func openPasteImportReview(_ payload: PasteImportReviewPayload) {
        pasteImport.beginReview()
        PasteImportReviewPresenter.shared.present(payload)
        openWindow(id: PasteImportReviewPresenter.windowID)
    }

    private func selectPasteImportBooking(_ id: UUID) {
        guard let booking = allBookings.first(where: { $0.id == id }) else {
            selection = .openBookings
            selectedOpenBookingIDs = [id]
            return
        }
        if let trip = booking.trip {
            selection = .trip(trip.id)
            selectedTimelineIDs = [id.uuidString]
            return
        }
        selection = OpenBookingMatching.unassignedList(endAt: booking.endAt) == .elapsed
            ? .elapsedOpenBookings
            : .openBookings
        selectedOpenBookingIDs = [id]
    }

    private func startCreateBooking(in trip: SDTrip) {
        applyAfterTripFocus(trip: trip) {
            expandedTripIDs.insert(trip.id)
            createDraftTypedTitle = ""
            bookingEditorSession = .create(prefillStart: nil, prefillEnd: nil)
            BookingCreateDraftDiagnostics.recordSelected(reason: "menu_or_sidebar_create_draft")
            Task { @MainActor in
                await Task.yield()
                guard case .create = bookingEditorSession else { return }
                var selection = selectedTimelineIDs
                BookingCreateDraftSelection.selectCreateDraft(into: &selection)
                selectedTimelineIDs = selection
            }
        }
    }

    private func expandedBinding(for tripID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedTripIDs.contains(tripID) },
            set: { newValue in
                if newValue {
                    expandedTripIDs.insert(tripID)
                } else {
                    expandedTripIDs.remove(tripID)
                }
            }
        )
    }
}
