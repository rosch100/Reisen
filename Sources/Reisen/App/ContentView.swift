import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenProviders
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

    @State private var showCreateTrip = false
    @State private var tripToEdit: SDTrip?
    @State private var tripPendingDelete: SDTrip?
    @State private var showTripDeleteConfirmation = false

    /// Selektion der mittleren Buchungsliste → rechte Detailspalte.
    @State private var selectedTimelineID: String? = nil
    @State private var bookingEditorSession: BookingEditorSession? = nil
    /// Lücke/Buchung-Titel Overrides aus dem Gap-Editor.
    @State private var gapOverrides: [String: TripDetailView.GapOverride] = [:]
    /// Payload des aktiven Gap-Editors (Sheet in Detailspalte).
    @State private var gapEditorPayload: TripDetailView.GapEditorPayload? = nil

    @State private var activeTripID: UUID? = nil

    /// Auswahl der offenen Buchung (Content → Detail, analog zu Mail-UX).
    @State private var selectedOpenBookingID: UUID?

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
    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .check24))
    private var check24Enabled: Bool
    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .opodo))
    private var opodoEnabled: Bool
    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .booking))
    private var bookingEnabled: Bool
    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .airbnb))
    private var airbnbEnabled: Bool

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
                        Label("Alle synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .help("Alle aktivierten, angemeldeten Provider nacheinander synchronisieren")
                .disabled(store?.isSyncing == true || syncAllCandidates.isEmpty)

                Button {
                    showCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Neue Reise anlegen")
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
            gapOverrides = [:]
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
            tripPendingDelete.map { "Reise „\($0.title)“ löschen?" } ?? "Reise löschen?",
            isPresented: $showTripDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                guard let trip = tripPendingDelete else { return }
                if selection == .trip(trip.id) {
                    selection = trips.first(where: { $0.id != trip.id }).map { .trip($0.id) }
                        ?? .providerSync(enabledProviderIDs.first ?? .check24)
                }
                modelContext.delete(trip)
                try? modelContext.save()
                tripPendingDelete = nil
            }
            Button("Abbrechen", role: .cancel) {
                tripPendingDelete = nil
            }
        } message: {
            Text("Die Reise und zugeordnete Lücken-Metadaten werden entfernt. Buchungen bleiben als offene Buchungen erhalten, sofern sie nicht gelöscht werden.")
        }
    }

    @ViewBuilder
    private var mainColumn: some View {
        if !sessionProbeFinished, selection == nil {
            ZStack {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Provider-Sitzungen prüfen…")
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
                    Label("Willkommen", systemImage: "airplane")
                } description: {
                    Text("Wähle eine Reise oder einen Provider in der Seitenleiste.")
                } actions: {
                    Button("Neue Reise anlegen") {
                        showCreateTrip = true
                    }
                    Button("Provider Sync öffnen") {
                        selection = .providerSync(enabledProviderIDs.first ?? .check24)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var globalSyncStatusBar: some View {
        if store?.messageProviderID == nil,
           let text = store?.statusMessage ?? store?.errorMessage,
           !text.isEmpty {
            HStack(spacing: 8) {
                if store?.isSyncing == true {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(text)
                    .font(.callout)
                    .foregroundStyle(store?.errorMessage != nil ? Color.red : Color.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
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

    private var enabledProviderIDs: [ProviderID] {
        var ids: [ProviderID] = []
        if check24Enabled { ids.append(.check24) }
        if opodoEnabled { ids.append(.opodo) }
        if bookingEnabled { ids.append(.booking) }
        if airbnbEnabled { ids.append(.airbnb) }
        return ids
    }

    private var syncAllCandidates: [(ProviderID, WKWebView)] {
        guard let sessionHub else { return [] }
        return enabledProviderIDs.compactMap { id in
            guard sessionHub.status(for: id) == .sessionReady,
                  let webView = sessionHub.webView(for: id) else { return nil }
            return (id, webView)
        }
    }

    @MainActor
    private func runSyncAll() async {
        guard let store else { return }
        let candidates = syncAllCandidates
        await store.syncAll(providers: candidates, settings: syncAllSettings)
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
            Section("Provider") {
                ProviderSidebarRow(providerID: .check24)
                    .tag(SidebarSelection.providerSync(.check24))

                ProviderSidebarRow(providerID: .opodo)
                    .tag(SidebarSelection.providerSync(.opodo))

                ProviderSidebarRow(providerID: .booking)
                    .tag(SidebarSelection.providerSync(.booking))

                ProviderSidebarRow(providerID: .airbnb)
                    .tag(SidebarSelection.providerSync(.airbnb))
            }

            Section("Offene Buchungen") {
                if openBookings.isEmpty {
                    Text("Keine offenen Buchungen")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        selection = .openBookings
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Offene Buchungen")
                                Text("\(openBookings.count) Einträge")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar.badge.plus")
                        }
                    }
                    .tag(SidebarSelection.openBookings)
                    .buttonStyle(.plain)
                }
            }

            Section {
                if trips.isEmpty {
                    Text("Noch keine Reisen")
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
                                    .help(isExpanded ? "Buchungen einklappen" : "Buchungen ausklappen")
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
                                                Text("\(tripBookings.count) Buchungen")
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
                                Button("Bearbeiten") {
                                    tripToEdit = trip
                                }
                                Button("Buchung hinzufügen…") {
                                    startCreateBooking(in: trip)
                                }
                                Button(role: .destructive) {
                                    tripPendingDelete = trip
                                    showTripDeleteConfirmation = true
                                } label: {
                                    Text("Reise löschen…")
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
                                            Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                                                .lineLimit(1)
                                            Text("\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))")
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
                                        Button("Bearbeiten") {
                                            editBooking(booking, in: trip)
                                        }
                                        Button("Buchung hinzufügen…") {
                                            startCreateBooking(in: trip, selectBookingID: booking.id)
                                        }
                                        if let urlString = booking.externalUrl,
                                           let url = URL(string: urlString),
                                           !urlString.hasPrefix("reisen://manual/") {
                                            Button("Buchung im Browser öffnen") {
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
                                            Text("Von Reise entfernen…")
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
                                                Text("Löschen…")
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
                    Text("Reisen")
                    Spacer()
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Neue Reise anlegen")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Reisen")
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }
    private var openBookings: [SDBooking] {
        allBookings.filter { booking in
            booking.trip == nil &&
            booking.startAt >= startOfToday &&
            booking.status != .cancelled
        }
    }

    private func matchingTrip(for booking: SDBooking) -> SDTrip? {
        trips.first { isOpenBookingCandidate(booking, for: $0) }
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
                    gapOverrides: $gapOverrides,
                    gapEditorPayload: $gapEditorPayload,
                    bookingEditorSession: $bookingEditorSession
                )
                .id(id)
            } else {
                ContentUnavailableView(
                    "Reise nicht gefunden",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Die ausgewählte Reise ist nicht mehr vorhanden.")
                )
            }
        case .providerSync(let providerID):
            ProviderSyncContainer(selectedProviderID: providerSyncSelectionBinding)
                .id(providerID)
        case .openBookings:
            if openBookings.isEmpty {
                ContentUnavailableView {
                    Label("Keine offenen Buchungen", systemImage: "calendar")
                } description: {
                    Text("Aktuell gibt es keine offenen Buchungen.")
                } actions: {
                    Button("Provider Sync öffnen") {
                        selection = .providerSync(enabledProviderIDs.first ?? .check24)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Offene Buchungen")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 4)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(openBookings) { booking in
                                Button {
                                    selectedOpenBookingID = booking.id
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                                            .lineLimit(1)
                                        Text("\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        selectedOpenBookingID == booking.id
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.clear
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if let urlString = booking.externalUrl,
                                       let url = URL(string: urlString),
                                       !urlString.hasPrefix("reisen://manual/") {
                                        Button("Buchung im Browser öffnen") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                    if let trip = matchingTrip(for: booking) {
                                        Button("In Reise zuordnen…") {
                                            applyAfterTripFocus(trip: trip) {
                                                NotificationCenter.default.post(
                                                    name: .reisenAssignBookings,
                                                    object: nil
                                                )
                                            }
                                        }
                                    }
                                }

                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .navigationTitle("Offene Buchungen")
                .onAppear {
                    if selectedOpenBookingID == nil, let first = openBookings.first?.id {
                        selectedOpenBookingID = first
                    }
                }
                .onChange(of: openBookings.count) { _, _ in
                    if let selectedOpenBookingID,
                       openBookings.contains(where: { $0.id == selectedOpenBookingID }) {
                        return
                    }
                    selectedOpenBookingID = openBookings.first?.id
                }
            }
        case .none, .trips:
            ContentUnavailableView(
                "Reise auswählen",
                systemImage: "airplane",
                description: Text("Wähle eine Reise in der Seitenleiste aus.")
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
                "Reisen",
                systemImage: "airplane",
                description: Text("Wähle eine Reise in der Seitenleiste oder synchronisiere zuerst einen Anbieter.")
            )
        case .openBookings:
            if let selectedOpenBookingID, let booking = openBookings.first(where: { $0.id == selectedOpenBookingID }) {
                OpenBookingDetailView(booking: booking)
                    .navigationTitle(booking.title ?? booking.bookingType.rawValue.capitalized)
            } else if let first = openBookings.first {
                OpenBookingDetailView(booking: first)
                    .navigationTitle(first.title ?? first.bookingType.rawValue.capitalized)
            } else {
                ContentUnavailableView(
                    "Keine offenen Buchungen",
                    systemImage: "calendar",
                    description: Text("Aktuell gibt es keine offenen Buchungen.")
                )
            }
        case .trip(let id):
            if let trip = trips.first(where: { $0.id == id }) {
                TripDetailView(
                    mode: .detail,
                    trip: trip,
                    selectedTimelineID: $selectedTimelineID,
                    gapOverrides: $gapOverrides,
                    gapEditorPayload: $gapEditorPayload,
                    bookingEditorSession: $bookingEditorSession
                )
                .id(id)
            } else {
                ContentUnavailableView(
                    "Reise nicht gefunden",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Die ausgewählte Reise ist nicht mehr vorhanden.")
                )
            }
        }
    }

    private struct OpenBookingDetailView: View {
        let booking: SDBooking

        /// Stornofristen in Hotel-/Unterkunfts-Zeitzone inkl. Uhrzeit (Booking.com HAR).
        private static func formatDeadline(_ deadline: SDCancellationDeadline, booking: SDBooking) -> String {
            let offset = deadline.hotelOffsetSeconds ?? booking.hotelOffsetSeconds
            let tz = offset.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.timeZone = tz
            formatter.dateFormat = "d. MMMM yyyy HH:mm"
            return formatter.string(from: deadline.deadlineAt)
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                                .font(.headline)
                                .textSelection(.enabled)
                            Text("\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !booking.cancellationDeadlines.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Storno")
                                    .font(.subheadline.weight(.semibold))

                                ForEach(booking.cancellationDeadlines.sorted(by: { $0.deadlineAt < $1.deadlineAt }), id: \.id) { deadline in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .foregroundStyle(.orange)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(Self.formatDeadline(deadline, booking: booking))
                                                    .font(.caption.weight(.medium))
                                                Text(deadline.isFreeCancellation ? "Kostenlos" : "Kostenpflichtig")
                                                    .font(.caption2)
                                                    .foregroundStyle(deadline.isFreeCancellation ? .green : .secondary)
                                            }
                                        }

                                        if let fee = deadline.cancellationFeeAmount {
                                            Text(formatCurrencyAmount(fee, currencyCode: booking.rateDetails?.totalPriceCurrency))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        if deadline.isStrict {
                                            Text("strikt")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        if let policy = deadline.policyText, !policy.isEmpty {
                                            Text(policy)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "Keine Storno-Infos",
                                systemImage: "info.circle",
                                description: Text("Für diese Buchung sind keine Stornobedingungen hinterlegt.")
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func dateRange(_ trip: SDTrip) -> String {
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }

    private func futureBookings(for trip: SDTrip) -> [SDBooking] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return trip.bookings
            .filter { $0.startAt >= startOfToday && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
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

