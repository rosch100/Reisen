import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenAppCore
import ReisenProviderSync
import ReisenSharedUI
import AppKit
import Foundation
import WebKit

struct ContentView: View {
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @State private var selection: SidebarSelection?
    @State private var expandedTripIDs: Set<UUID> = []
    @State private var didInitExpanded = false
    @State private var didRunTimeRepair = false
    @State private var didApplyInitialSelection = false
    @State private var sessionProbeFinished = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncStore) private var store
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.providerRegistry) private var providerRegistry

    @State private var providerEnableEpoch = 0
    @State private var showCreateTrip = false
    @State private var tripToEdit: SDTrip?
    @State private var tripPendingDelete: SDTrip?
    @State private var showTripDeleteConfirmation = false

    /// Selektion der mittleren Buchungsliste → rechte Detailspalte.
    @State private var selectedTimelineID: String? = nil
    @State private var bookingEditorSession: BookingEditorSession? = nil
    /// Payload des aktiven Gap-Editors (Sheet in Detailspalte).
    @State private var gapEditorPayload: GapEditorPayload? = nil

    @State private var activeTripID: UUID? = nil

    /// Auswahl der offenen Buchung (Content → Detail, analog zu Mail-UX).
    @State private var selectedOpenBookingIDs: Set<UUID> = []
    @State private var tripCreateSeed: TripCreateSeed?
    @State private var showCreateTripFromBookingsFailed = false

    /// HIG: Spalten per dünnem Divider ziehbar (keine sichtbaren Slider-Knöpfe).
    private let sidebarMinWidth: CGFloat = 180
    private let sidebarMaxWidth: CGFloat = 420
    private let bookingListMinWidth: CGFloat = 280
    private let detailMinWidth: CGFloat = 280

    @AppStorage(AppSettingsKeys.notificationEnabled) private var notificationEnabled: Bool = true
    @AppStorage(AppSettingsKeys.eventKitEnabled) private var eventKitEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitle) private var calendarTitle: String = "Reisen"
    @AppStorage(AppSettingsKeys.reminderCalendarTitle) private var reminderCalendarTitle: String = "Reisen"
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenShowProviderSync)) { note in
            if let providerID = note.object as? ProviderID {
                selection = .providerSync(providerID)
            } else {
                selection = .providerSync(enabledProviderIDs.first ?? .check24)
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
            if !didInitExpanded {
                // Reisen standardmäßig eingeklappt; Nutzer kann aufklappen.
                expandedTripIDs = []
                didInitExpanded = true
            }

            if !didRunTimeRepair {
                didRunTimeRepair = true
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
        .onChange(of: selection?.tripID) { _, newTripID in
            guard newTripID != activeTripID else { return }
            activeTripID = newTripID
            selectedTimelineID = nil
            gapEditorPayload = nil
        }
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
        .confirmationDialog(
            tripPendingDelete.map { L10n.format(.tripDeleteConfirmTitleNamed, $0.title) }
                ?? L10n.string(.actionDeleteTripConfirm),
            isPresented: $showTripDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string(.commonDelete), role: .destructive) {
                guard let trip = tripPendingDelete else { return }
                if selection == .trip(trip.id) {
                    selection = trips.first(where: { $0.id != trip.id }).map { .trip($0.id) }
                        ?? .providerSync(enabledProviderIDs.first ?? .check24)
                }
                try? TripDeletion.perform(trip: trip, in: modelContext)
                tripPendingDelete = nil
            }
            Button(L10n.string(.commonCancel), role: .cancel) {
                tripPendingDelete = nil
            }
        } message: {
            Text(L10n.string(.tripDeleteConfirmMessage))
        }
        .focusedSceneValue(
            \.openBookingsCommandState,
            selection == .openBookings && !selectedOpenBookingIDs.isEmpty
                ? OpenBookingsCommandState(canCreateTripFromSelection: true)
                : nil
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
        } else {
            switch selection {
            case .providerSync:
                ProviderSyncContainer(selectedProviderID: providerSyncSelectionBinding)
            case .trip, .openBookings:
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
                    Text(L10n.string(.tripSelectSidebarOrProvider))
                } actions: {
                    Button(L10n.string(.actionCreateTrip)) {
                        showCreateTrip = true
                    }
                    Button(L10n.string(.actionOpenSync)) {
                        selection = .providerSync(enabledProviderIDs.first ?? .check24)
                    }
                }
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
        await SyncAllCoordinator.run(
            syncStore: store,
            enabledProviderIDs: enabledProviderIDs,
            sessionHub: sessionHub,
            settings: syncAllSettings,
            navigationHints: { id in
                NavigationHintURLs.ordered(hubURLString: sessionHub.lastURLString(for: id))
            }
        )
    }

    private func handleSessionProbeFinished(needingLogin: [ProviderID]) {
        AgentDebugLog.write(
            hypothesisId: "BOOT",
            location: "ContentView.swift:handleSessionProbeFinished",
            message: "session probe finished",
            data: ["needingLogin": needingLogin.map(\.rawValue).joined(separator: ",")]
        )
        sessionProbeFinished = true
        guard !didApplyInitialSelection else { return }
        didApplyInitialSelection = true

        if let firstLogin = needingLogin.first {
            selection = .providerSync(firstLogin)
        } else if let trip = trips.first {
            selection = .trip(trip.id)
        } else {
            selection = .providerSync(enabledProviderIDs.first ?? .check24)
        }
    }

    /// Binding für Provider-Sync-Auswahl (Sidebar ↔ Login-Queue-Orchestrator).
    private var providerSyncSelectionBinding: Binding<ProviderID> {
        Binding(
            get: {
                if case .providerSync(let id) = selection { return id }
                return enabledProviderIDs.first ?? .check24
            },
            set: { selection = .providerSync($0) }
        )
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section(L10n.string(.syncProvider)) {
                ForEach(registeredProviderIDs, id: \.self) { providerID in
                    ProviderSidebarRow(providerID: providerID)
                        .tag(SidebarSelection.providerSync(providerID))
                }
            }

            Section(L10n.string(.tripOpenBookings)) {
                if openBookings.isEmpty {
                    Text(L10n.string(.tripNoOpenBookings))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        selection = .openBookings
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.string(.tripOpenBookings))
                                Text(L10n.format(.tripOpenEntries, openBookings.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar.badge.plus")
                        }
                    }
                    .tag(SidebarSelection.openBookings)
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            selection = .openBookings
                            selectedOpenBookingIDs = Set(openBookings.map(\.id))
                            OpenBookingCreateTripAction.assignSeedFromAll(
                                in: allBookings,
                                seed: $tripCreateSeed,
                                showFailed: $showCreateTripFromBookingsFailed
                            )
                        } label: {
                            CreateTripFromAllOpenBookingsLabel(count: openBookings.count)
                        }
                    }
                }
            }

            Section {
                if trips.isEmpty {
                    Text(L10n.string(.tripNoTripsYet))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trips) { trip in
                        let tripBookings = futureBookings(for: trip)
                        let isExpanded = expandedTripIDs.contains(trip.id)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                if !tripBookings.isEmpty {
                                    Button {
                                        expandedBinding(for: trip.id).wrappedValue.toggle()
                                    } label: {
                                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 14, height: 14)
                                    }
                                    .buttonStyle(.plain)
                                    .help(isExpanded
                                        ? L10n.string(.tripCollapseBookings)
                                        : L10n.string(.tripExpandBookings))
                                }

                                Button {
                                    selection = .trip(trip.id)
                                } label: {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(trip.title)
                                            Text(dateRange(trip))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if !tripBookings.isEmpty {
                                                Text(L10n.format(.tripBookingCount, tripBookings.count))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: "airplane")
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .tag(SidebarSelection.trip(trip.id))
                            .contextMenu {
                                Button(L10n.string(.commonEdit)) {
                                    tripToEdit = trip
                                }
                                Button(L10n.string(.actionAddBooking)) {
                                    startCreateBooking(in: trip)
                                }
                                Button(role: .destructive) {
                                    tripPendingDelete = trip
                                    showTripDeleteConfirmation = true
                                } label: {
                                    Text(L10n.string(.actionDeleteTrip))
                                }
                            }

                            if isExpanded {
                                ForEach(tripBookings) { booking in
                                    let isBookingSelected = selection == .trip(trip.id)
                                        && selectedTimelineID == booking.id.uuidString
                                    Button {
                                        selection = .trip(trip.id)
                                        selectedTimelineID = booking.id.uuidString
                                        if !expandedTripIDs.contains(trip.id) {
                                            expandedTripIDs.insert(trip.id)
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(booking.presentationTitle)
                                                .lineLimit(1)
                                            Text(BookingScheduleRangeText.make(for: booking))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
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
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button(L10n.string(.commonEdit)) {
                                            editBooking(booking, in: trip)
                                        }
                                        Button(L10n.string(.actionAddBooking)) {
                                            startCreateBooking(in: trip, selectBookingID: booking.id)
                                        }
                                        if let url = booking.browserURL {
                                            Button(L10n.string(.actionOpenInBrowser)) {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }
                                        Button(role: .destructive) {
                                            applyAfterTripFocus(trip: trip) {
                                                selectedTimelineID = booking.id.uuidString
                                                NotificationCenter.default.post(
                                                    name: .reisenRequestRemoveBookingFromTrip,
                                                    object: booking.id
                                                )
                                            }
                                        } label: {
                                            Text(L10n.string(.actionRemoveFromTrip))
                                        }
                                        if booking.provider == .manual {
                                            Button(role: .destructive) {
                                                applyAfterTripFocus(trip: trip) {
                                                    selectedTimelineID = booking.id.uuidString
                                                    NotificationCenter.default.post(
                                                        name: .reisenRequestDeleteManualBooking,
                                                        object: booking.id
                                                    )
                                                }
                                            } label: {
                                                Text(L10n.string(.actionDeleteEllipsis))
                                            }
                                        }
                                    }
                                }
                            }
                        }
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
        }
        .listStyle(.sidebar)
        .navigationTitle(L10n.string(.tripTrips))
    }

    private var openBookings: [SDBooking] {
        OpenBookingMatching.openUnassigned(in: allBookings)
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
                    selectedTimelineID: $selectedTimelineID,
                    gapEditorPayload: $gapEditorPayload,
                    bookingEditorSession: $bookingEditorSession
                )
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
                    Button(L10n.string(.actionOpenSync)) {
                        selection = .providerSync(enabledProviderIDs.first ?? .check24)
                    }
                }
            } else {
                List(openBookings, selection: $selectedOpenBookingIDs) { booking in
                    OpenBookingRow(booking: booking)
                        .tag(booking.id)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .navigationTitle(L10n.string(.tripOpenBookings))
                .contextMenu(forSelectionType: UUID.self) { selectedIDs in
                    if selectedIDs.count == 1,
                       let bookingID = selectedIDs.first,
                       let booking = openBookings.first(where: { $0.id == bookingID }) {
                        if let url = booking.browserURL {
                            Button(L10n.string(.actionOpenInBrowser)) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        if let trip = matchingTrip(for: booking) {
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
                    if !selectedIDs.isEmpty {
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
            ProviderSyncContainer(selectedProviderID: .constant(.check24))
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
                        }
                    )
                    .padding(16)
                }
                .navigationTitle(L10n.string(.tripOpenBookings))
            } else if let bookingID = selectedOpenBookingIDs.first,
                      let booking = openBookings.first(where: { $0.id == bookingID }) {
                OpenBookingDetailView(
                    booking: booking,
                    matchingTrip: matchingTrip(for: booking),
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
        case .trip(let id):
            if let trip = trips.first(where: { $0.id == id }) {
                TripDetailView(
                    mode: .detail,
                    trip: trip,
                    selectedTimelineID: $selectedTimelineID,
                    gapEditorPayload: $gapEditorPayload,
                    bookingEditorSession: $bookingEditorSession
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
        var onCreateTrip: () -> Void

        @Environment(\.modelContext) private var modelContext
        @State private var assignErrorMessage: String?
        @State private var showAssignError = false
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
                        showsSyncOverwriteHint: booking.provider != .manual,
                        draft: draftBinding,
                        providerReadOnly: booking.provider != .manual,
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
            .bookingDeleteConfirmDialog(
                showDeleteConfirmation: $showDeleteConfirmation,
                onConfirmDelete: deletePendingBooking,
                onCancelDelete: { pendingDeleteBookingID = nil }
            )
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
                                onEditBooking: {
                                    isEditing = true
                                    bookingEditorDraft = BookingEditorDraft.fromExisting(booking)
                                },
                                onRequestManualDeleteBooking: { bookingID in
                                    pendingDeleteBookingID = bookingID
                                    showDeleteConfirmation = true
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
            modelContext.delete(booking)
            do {
                try modelContext.save()
            } catch {
                assignErrorMessage = error.localizedDescription
                showAssignError = true
                modelContext.rollback()
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

    private func futureBookings(for trip: SDTrip) -> [SDBooking] {
        trip.timelineBookings()
    }

    private func focusTrip(_ trip: SDTrip) {
        selection = .trip(trip.id)
        expandedTripIDs.insert(trip.id)
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
            selectedTimelineID = booking.id.uuidString
            bookingEditorSession = .edit(bookingID: booking.id)
        }
    }

    private func startCreateBooking(in trip: SDTrip, selectBookingID: UUID? = nil) {
        applyAfterTripFocus(trip: trip) {
            if let selectBookingID {
                selectedTimelineID = selectBookingID.uuidString
            }
            bookingEditorSession = .create(prefillStart: nil, prefillEnd: nil)
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

