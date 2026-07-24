import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

@main
struct ReiseniOSApp: App {
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap.state {
                case .ready(let container, let registry, let syncStore, let sessionHub):
                    RootTabView()
                        .environment(\.providerRegistry, registry)
                        .environment(\.syncStore, syncStore)
                        .environment(\.providerSessionHub, sessionHub)
                        .modelContainer(container)
                case .failed(let message):
                    StoreFailureViewIOS(message: message) {
                        bootstrap.resetStoreAndRetry()
                    }
                }
            }
        }
    }
}

private struct StoreFailureViewIOS: View {
    let message: String
    let onReset: () -> Void

    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Datenbank konnte nicht geladen werden")
                .font(.title2)
            Text(message)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)

            Button("Lokale Datenbank zurücksetzen und erneut versuchen…") {
                showResetConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .confirmationDialog(
                "Lokale Datenbank zurücksetzen?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Zurücksetzen", role: .destructive) {
                    onReset()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Alle lokal gespeicherten Reisen und Buchungen werden unwiderruflich gelöscht.")
            }
        }
        .padding(24)
    }
}

private let iosSyncProviderIDs: [ProviderID] = [.check24, .opodo, .booking, .airbnb]

private struct RootTabView: View {
    @State private var isShowingSettings = false
    /// Erzwingt Toolbar-Refresh, wenn Hintergrund-Probes den SessionHub aktualisieren
    /// (optional Environment + @Observable tracked sonst nicht zuverlässig über Tabs).
    @State private var sessionChromeEpoch = 0

    @ViewBuilder
    var body: some View {
        ZStack {
            Group {
                if #available(iOS 18.0, *) {
                    tabs
                        .tabViewStyle(.sidebarAdaptable)
                } else {
                    tabs
                }
            }

            // Hintergrund-Session-Probe: Läuft unabhängig vom aktiven Tab,
            // damit Provider (z. B. Check24) im Hintergrund als „sessionReady“ erkannt werden.
            SyncBackgroundSessionProbe(onSessionChanged: {
                sessionChromeEpoch &+= 1
            })
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Einstellungen")
            }
        }
    }

    private var tabs: some View {
        TabView {
            ReisenTab(
                isShowingSettings: $isShowingSettings,
                sessionChromeEpoch: $sessionChromeEpoch
            )
            .tabItem {
                Label("Reisen", systemImage: "airplane")
            }

            OffenTab(
                isShowingSettings: $isShowingSettings,
                sessionChromeEpoch: $sessionChromeEpoch
            )
            .tabItem {
                Label("Offen", systemImage: "list.bullet.rectangle")
            }

            SyncTab(
                isShowingSettings: $isShowingSettings,
                sessionChromeEpoch: $sessionChromeEpoch
            )
            .tabItem {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }
}

/// Gemeinsame Trailing-Toolbar: Settings + Sync-All (über alle Tabs konsistent).
private struct GlobalChromeTrailingToolbar: View {
    @Binding var isShowingSettings: Bool
    /// Nur für Re-Render bei Hub-Änderungen aus Hintergrund-Probes / SyncTab.
    @Binding var sessionChromeEpoch: Int

    @Environment(\.syncStore) private var syncStore
    @Environment(\.providerSessionHub) private var sessionHub

    @AppStorage(AppSettingsKeys.notificationEnabled) private var notificationEnabled: Bool = true
    @AppStorage(AppSettingsKeys.eventKitEnabled) private var eventKitEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTripTimesEnabled) private var calendarTripTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarFlightTimesEnabled) private var calendarFlightTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarHotelStaysEnabled) private var calendarHotelStaysEnabled: Bool = false

    private var syncAllSettings: AppSettings {
        AppSettings(
            notificationEnabled: notificationEnabled,
            eventKitEnabled: eventKitEnabled,
            calendarTripTimesEnabled: calendarTripTimesEnabled,
            calendarFlightTimesEnabled: calendarFlightTimesEnabled,
            calendarHotelStaysEnabled: calendarHotelStaysEnabled
        )
    }

    private var syncAllCandidates: [(ProviderID, WKWebView)] {
        // sessionChromeEpoch bewusst lesen, damit Toolbar nach Probe-Updates neu evaluated.
        _ = sessionChromeEpoch
        guard let hub = sessionHub else { return [] }
        return iosSyncProviderIDs.compactMap { id in
            guard hub.status(for: id) == .sessionReady,
                  let webView = hub.webView(for: id) else { return nil }
            return (id, webView)
        }
    }

    private var canStartSyncAll: Bool {
        guard let syncStore else { return false }
        guard syncStore.isSyncing != true else { return false }
        return !syncAllCandidates.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .help("Einstellungen öffnen")

            Button {
                guard let syncStore else { return }
                let candidates = syncAllCandidates
                guard !candidates.isEmpty else { return }
                Task {
                    await syncStore.syncAll(providers: candidates, settings: syncAllSettings)
                }
            } label: {
                if syncStore?.isSyncing == true && syncStore?.syncingProviderID != nil {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(!canStartSyncAll)
            .help(canStartSyncAll
                ? "Synchronisiert alle angemeldeten Provider (sequenziell) im Hintergrund"
                : "Keine angemeldeten Provider für Sync-All")
        }
    }
}

private struct SyncBackgroundSessionProbe: View {
    var onSessionChanged: () -> Void

    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.providerSessionHub) private var sessionHub

    @State private var webViewsByProvider: [ProviderID: WKWebView?] = [:]

    private func loginURL(for providerID: ProviderID) -> URL? {
        let provider = providerRegistry?.provider(id: providerID)
        let loginConfig = provider as? any TravelProviderLoginConfiguration
        return loginConfig?.loginURL
    }

    private func webViewBinding(for providerID: ProviderID) -> Binding<WKWebView?> {
        Binding(
            get: { webViewsByProvider[providerID] ?? nil },
            set: { webViewsByProvider[providerID] = $0 }
        )
    }

    @MainActor
    private func ensureSlots() {
        sessionHub?.syncEnabledProviders(Set(iosSyncProviderIDs))
    }

    @MainActor
    private func handleWebNavigationDidFinish(providerID: ProviderID, _ finishedWebView: WKWebView) {
        ensureSlots()
        guard let hub = sessionHub else { return }
        guard let url = finishedWebView.url else { return }

        let heuristic = ProviderSessionStatusResolver.classify(url)
        let currentStatus = hub.status(for: providerID)
        hub.updateLastURL(providerID, urlString: url.absoluteString)
        hub.updateWebView(providerID, webView: finishedWebView)

        let previousReady = currentStatus == .sessionReady
        switch heuristic {
        case .sessionReady:
            hub.updateStatus(providerID, status: .sessionReady)
        case .needsLogin:
            // Wenn bereits `sessionReady` erkannt wurde, darf ein späterer Login-Look nicht downgraden.
            if currentStatus != .sessionReady {
                hub.updateStatus(providerID, status: .needsLogin)
            }
        case .shouldProbeOpodo:
            if currentStatus != .sessionReady {
                hub.updateStatus(providerID, status: .needsLogin)
            }
            Task {
                do {
                    let text = try await finishedWebView.fetchAuthenticatedText(
                        url: OpodoSessionProbe.graphqlURL,
                        method: "POST",
                        accept: "application/json",
                        referer: "https://www.opodo.de/",
                        contentType: "application/json",
                        body: OpodoSessionProbe.getUserAccountRequestBody()
                    )
                    if let loggedIn = OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: text) {
                        await MainActor.run {
                            ensureSlots()
                            if loggedIn {
                                hub.updateStatus(providerID, status: .sessionReady)
                            } else if hub.status(for: providerID) != .sessionReady {
                                hub.updateStatus(providerID, status: .needsLogin)
                            }
                            onSessionChanged()
                        }
                    }
                } catch {
                    // Probe fehlgeschlagen: Status bleibt konservativ.
                }
            }
        case .unknown:
            if currentStatus != .sessionReady {
                hub.updateStatus(providerID, status: .needsLogin)
            }
        }

        let nowReady = hub.status(for: providerID) == .sessionReady
        if previousReady != nowReady || nowReady {
            onSessionChanged()
        }
    }

    var body: some View {
        ZStack {
            ForEach(iosSyncProviderIDs, id: \.self) { id in
                WebViewHost(
                    loginURL: loginURL(for: id),
                    providerID: id,
                    webView: webViewBinding(for: id),
                    onDidFinish: { finishedWebView in
                        handleWebNavigationDidFinish(providerID: id, finishedWebView)
                    }
                )
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onAppear {
            ensureSlots()
        }
        .task {
            ensureSlots()
        }
    }
}

private struct ReisenTab: View {
    @Binding var isShowingSettings: Bool
    @Binding var sessionChromeEpoch: Int

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]
    @State private var showCreateTrip = false
    @State private var selectedTripID: UUID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    NavigationLink(destination: TripDetailIOS(tripID: trip.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.title)
                                .font(.headline)
                            Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Reisen")
            .navigationDestination(item: $selectedTripID) { tripID in
                TripDetailIOS(tripID: tripID)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Neue Reise anlegen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    GlobalChromeTrailingToolbar(
                        isShowingSettings: $isShowingSettings,
                        sessionChromeEpoch: $sessionChromeEpoch
                    )
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                TripEditorSheet(
                    mode: .create,
                    onSaved: { newTrip in
                        selectedTripID = newTrip.id
                    }
                )
            }
        }
    }
}

private struct OffenTab: View {
    @Binding var isShowingSettings: Bool
    @Binding var sessionChromeEpoch: Int
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            OpenBookingsScreen()
                .navigationTitle("Offen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreateTrip = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Neue Reise anlegen")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        GlobalChromeTrailingToolbar(
                            isShowingSettings: $isShowingSettings,
                            sessionChromeEpoch: $sessionChromeEpoch
                        )
                    }
                }
                .sheet(isPresented: $showCreateTrip) {
                    TripEditorSheet(
                        mode: .create,
                        onSaved: { _ in
                            // Auf „Offen“ nicht automatisch navigieren — Header/Tab bleibt konsistent.
                        }
                    )
                }
        }
    }
}

private struct OpenBookingsScreen: View {
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]

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

    var body: some View {
        Group {
            if openBookings.isEmpty {
                ContentUnavailableView(
                    "Keine offenen Buchungen",
                    systemImage: "calendar",
                    description: Text("Aktuell gibt es keine Buchungen, die noch keiner Reise zugeordnet sind.")
                )
            } else {
                List(openBookings, id: \.id) { booking in
                    NavigationLink(destination: BookingDetailIOS(bookingID: booking.id)) {
                        OpenBookingRow(booking: booking)
                    }
                }
            }
        }
    }
}

private struct OpenBookingRow: View {
    let booking: SDBooking

    private struct SummaryStornoLine: Identifiable {
        let id: String
        let systemImage: String
        let text: String
        let color: Color
    }

    private var hotelTimeZone: TimeZone {
        if let offsetSeconds = booking.hotelOffsetSeconds,
           let tz = TimeZone(secondsFromGMT: offsetSeconds) {
            return tz
        }
        if let offsetSeconds = booking.cancellationDeadlines.compactMap(\.hotelOffsetSeconds).first,
           let tz = TimeZone(secondsFromGMT: offsetSeconds) {
            return tz
        }
        return .current
    }

    private func bookingSummaryStornoLines(now: Date = Date()) -> [SummaryStornoLine] {
        guard !booking.cancellationDeadlines.isEmpty else { return [] }

        let domainDeadlines = booking.cancellationDeadlines.map(DomainMapper.deadline(from:))
        let service = CancellationDeadlineDisplayService()
        let summaryLines = service.summaryLines(
            deadlines: domainDeadlines,
            hotelTimeZone: hotelTimeZone,
            now: now
        )

        return summaryLines.map { summaryLine in
            let color: Color = {
                switch summaryLine.kind {
                case .fix, .paid:
                    return .secondary
                case .free:
                    guard let urgency = summaryLine.urgency else { return .secondary }
                    switch urgency {
                    case .ok: return .green
                    case .warning: return .orange
                    case .critical: return .red
                    case .fix: return .secondary
                    }
                }
            }()

            return SummaryStornoLine(
                id: summaryLine.id.uuidString,
                systemImage: summaryLine.systemImageName,
                text: summaryLine.text,
                color: color
            )
        }
    }

    var body: some View {
        let stornoLines = bookingSummaryStornoLines()

        VStack(alignment: .leading, spacing: 4) {
            Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                .lineLimit(1)
                .font(.headline)

            Text("\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !stornoLines.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(stornoLines) { line in
                        Label {
                            Text(line.text)
                                .font(.caption)
                                .foregroundStyle(line.color)
                                .lineLimit(2)
                        } icon: {
                            Image(systemName: line.systemImage)
                                .font(.caption)
                                .foregroundStyle(line.color)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }
}

private struct BookingDetailIOS: View {
    let bookingID: UUID

    @Environment(\.modelContext) private var modelContext
    @Query private var bookings: [SDBooking]
    @Query private var trips: [SDTrip]

    @State private var assignErrorMessage: String?
    @State private var showAssignError = false

    @State private var isEditing = false
    @State private var bookingEditorDraft: BookingEditorDraft?

    @State private var pendingDeleteBookingID: UUID?
    @State private var showDeleteConfirmation = false

    @State private var pendingRemoveFromTripBookingID: UUID?
    @State private var showRemoveFromTripConfirmation = false

    private var booking: SDBooking? {
        bookings.first(where: { $0.id == bookingID })
    }

    private var bookingTrip: SDTrip? {
        guard let booking else { return nil }
        return booking.trip
    }

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private func isOpenBookingCandidate(
        _ booking: SDBooking,
        for trip: SDTrip
    ) -> Bool {
        guard booking.trip == nil, booking.status != .cancelled else { return false }
        let tripStartDay = Calendar.current.startOfDay(for: trip.startDate)
        let tripEndDay = Calendar.current.startOfDay(for: trip.endDate)
        let bookingStartDay = Calendar.current.startOfDay(for: booking.startAt)
        let bookingEndDay = Calendar.current.startOfDay(for: booking.endAt)
        return bookingStartDay >= startOfToday
            && bookingStartDay >= tripStartDay
            && bookingEndDay <= tripEndDay
    }

    private var matchingTrip: SDTrip? {
        guard let booking, booking.trip == nil else { return nil }
        return trips.first { isOpenBookingCandidate(booking, for: $0) }
    }

    private var externalURL: URL? {
        guard let booking,
              let urlString = booking.externalUrl,
              let url = URL(string: urlString),
              !urlString.hasPrefix("reisen://manual/") else {
            return nil
        }
        return url
    }

    private var hotelTimeZone: TimeZone {
        if let offsetSeconds = booking?.hotelOffsetSeconds,
           let tz = TimeZone(secondsFromGMT: offsetSeconds) {
            return tz
        }
        if let deadlineOffset = booking?.cancellationDeadlines.compactMap(\.hotelOffsetSeconds).first,
           let tz = TimeZone(secondsFromGMT: deadlineOffset) {
            return tz
        }
        return TimeZone(secondsFromGMT: 0) ?? .current
    }

    private var draftBinding: Binding<BookingEditorDraft>? {
        guard bookingEditorDraft != nil else { return nil }
        return Binding(
            get: { bookingEditorDraft! },
            set: { bookingEditorDraft = $0 }
        )
    }

    private var bookingNavigationTitle: String {
        booking?.title
            ?? booking?.bookingType.rawValue.capitalized
            ?? "Buchung"
    }

    private func deletePendingBooking() {
        guard let bookingID = pendingDeleteBookingID,
              let bookingToDelete = bookings.first(where: { $0.id == bookingID }) else { return }
        modelContext.delete(bookingToDelete)
        try? modelContext.save()
        pendingDeleteBookingID = nil
    }

    private func removePendingBookingFromTrip() {
        guard let bookingID = pendingRemoveFromTripBookingID,
              let bookingToRemove = bookings.first(where: { $0.id == bookingID }) else { return }
        bookingToRemove.trip = nil
        try? modelContext.save()
        pendingRemoveFromTripBookingID = nil
    }

    @ViewBuilder
    private func bookingActionsSection(for booking: SDBooking) -> some View {
        Section {
            Button {
                isEditing = true
                bookingEditorDraft = BookingEditorDraft.fromExisting(booking)
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .help("Diese Buchung bearbeiten")

            if booking.provider == .manual {
                Button(role: .destructive) {
                    pendingDeleteBookingID = booking.id
                    showDeleteConfirmation = true
                } label: {
                    Text("Löschen…")
                }
                .help("Diese manuelle Buchung unwiderruflich löschen")
            }

            if booking.trip != nil {
                Button(role: .destructive) {
                    pendingRemoveFromTripBookingID = booking.id
                    showRemoveFromTripConfirmation = true
                } label: {
                    Text("Von Reise entfernen…")
                }
                .help("Diese Buchung aus der Reise lösen und unter „Offene Buchungen“ anzeigen")
            }
        }
    }

    @ViewBuilder
    private func bookingRateSections(for booking: SDBooking) -> some View {
        if let rate = booking.rateDetails {
            Section("Preis / Tarif") {
                BookingDetailIOSRateDetailsView(rate: rate, booking: booking)
            }

            if !rate.roomItems.isEmpty {
                Section("Zimmer / Positionen") {
                    BookingDetailIOSRoomItemsView(rate: rate)
                }
            }
        }
    }

    @ViewBuilder
    private func bookingAssignmentSection(for booking: SDBooking) -> some View {
        Section("Zuordnung") {
            if let trip = bookingTrip {
                Text("In Reise: \(trip.title)")
                    .foregroundStyle(.secondary)
            } else if let trip = matchingTrip {
                Button("In Reise zuordnen…") {
                    do {
                        booking.trip = trip
                        try modelContext.save()
                    } catch {
                        assignErrorMessage = error.localizedDescription
                        showAssignError = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .help("Diese offene Buchung der passenden Reise zuordnen")
            } else {
                Text("Keine passende Reise gefunden.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bookingLinksSection(for booking: SDBooking) -> some View {
        Section("Links") {
            if let externalURL {
                Link("Buchung im Browser öffnen", destination: externalURL)
            } else {
                Text("Kein Browser-Link verfügbar.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bookingOverviewSection(for booking: SDBooking) -> some View {
        Section("Übersicht") {
            VStack(alignment: .leading, spacing: 6) {
                Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                    .font(.headline)
                    .textSelection(.enabled)

                Text("\(booking.bookingType.rawValue.capitalized) • \(booking.provider.rawValue.capitalized)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                let startText = booking.startAt.formatted(date: .abbreviated, time: .omitted)
                let endText = booking.endAt.formatted(date: .abbreviated, time: .omitted)
                HStack(spacing: 4) {
                    Text("Zeitraum:")
                    Text(startText)
                    Text("–")
                    Text(endText)
                }
                .foregroundStyle(.secondary)

                if let code = booking.confirmationCode, !code.isEmpty {
                    Text("Bestätigung: \(code)")
                        .foregroundStyle(.secondary)
                }

                if let synced = booking.lastSyncedAt {
                    let syncedText = synced.formatted(date: .abbreviated, time: .shortened)
                    HStack(spacing: 4) {
                        Text("Zuletzt synchronisiert:")
                        Text(syncedText)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
        }
    }

    var body: some View {
        Group {
            if let booking {
                List {
                    bookingOverviewSection(for: booking)

                    bookingAssignmentSection(for: booking)

                    Section("Details") {
                        AnyView(BookingDetailIOSDetailsView(booking: booking))
                    }

                    bookingRateSections(for: booking)

                    if !booking.cancellationDeadlines.isEmpty {
                        Section("Stornierung") {
                            BookingDetailIOSCancellationDeadlinesView(
                                booking: booking,
                                hotelTimeZone: hotelTimeZone
                            )
                        }
                    }

                    bookingLinksSection(for: booking)

                    bookingActionsSection(for: booking)
                }
            } else {
                ContentUnavailableView(
                    "Buchung nicht gefunden",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Die ausgewählte Buchung ist nicht mehr verfügbar.")
                )
            }
        }
        .navigationTitle(bookingNavigationTitle)
        .alert("Zuordnung fehlgeschlagen", isPresented: $showAssignError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = assignErrorMessage, !message.isEmpty {
                Text(message)
            }
        }
        .confirmationDialog(
            "Buchung wirklich löschen?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { deletePendingBooking() }
            Button("Abbrechen", role: .cancel) {
                pendingDeleteBookingID = nil
            }
        }
        .confirmationDialog(
            "Buchung von Reise entfernen?",
            isPresented: $showRemoveFromTripConfirmation,
            titleVisibility: .visible
        ) {
            Button("Entfernen", role: .destructive) { removePendingBookingFromTrip() }
            Button("Abbrechen", role: .cancel) {
                pendingRemoveFromTripBookingID = nil
            }
        } message: {
            Text("Die Buchung wird der Reise entzogen und erscheint unter „Offene Buchungen“.")
        }
        .sheet(isPresented: $isEditing) {
            if let draftBinding {
                BookingEditorForm(
                    title: "Buchung bearbeiten",
                    showsSyncOverwriteHint: booking?.provider == .manual ? false : true,
                    draft: draftBinding,
                    providerReadOnly: booking?.provider == .manual ? false : true,
                    onCancel: {
                        isEditing = false
                        bookingEditorDraft = nil
                    },
                    onSave: {
                        guard let booking else { return }
                        guard let draft = bookingEditorDraft else { return }
                        try draft.apply(to: booking, in: modelContext)
                        isEditing = false
                        bookingEditorDraft = nil
                    }
                )
            }
        }
    }
}

private struct BookingDetailIOSDetailsView: View {
    let booking: SDBooking

    private var hotelStartText: String {
        HotelStayDate.format(
            booking.startAt,
            dateFormat: "d.M.yyyy",
            legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
        )
    }

    private var hotelEndText: String {
        HotelStayDate.format(
            booking.endAt,
            dateFormat: "d.M.yyyy",
            legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
        )
    }

    private var flightDepartureTZ: TimeZone {
        booking.flightDepartureOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
    }

    private var flightArrivalTZ: TimeZone {
        booking.flightArrivalOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
    }

    private var flightStartText: String {
        Formatting.formatOrtszeit(
            booking.startAt,
            dateFormat: "d.M.yyyy HH:mm",
            timeZone: flightDepartureTZ
        )
    }

    private var flightEndText: String {
        Formatting.formatOrtszeit(
            booking.endAt,
            dateFormat: "d.M.yyyy HH:mm",
            timeZone: flightArrivalTZ
        )
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Status: \(booking.status.rawValue.capitalized)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(booking.bookingType.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private var locationsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let from = booking.locationFrom, !from.isEmpty {
                Text("Von: \(from)")
                    .foregroundStyle(.secondary)
            }
            if let to = booking.locationTo, !to.isEmpty {
                Text("Nach: \(to)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hotelDateView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Start: \(hotelStartText)")
                .foregroundStyle(.secondary)
            Text("Ende: \(hotelEndText)")
                .foregroundStyle(.secondary)

            if let checkIn = booking.hotelCheckInMinutes {
                Text("Check-in: \(Formatting.minutesToHHmm(checkIn))")
                    .foregroundStyle(.secondary)
            }
            if let checkOut = booking.hotelCheckOutMinutes {
                Text("Check-out: \(Formatting.minutesToHHmm(checkOut))")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var flightDateView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Start: \(flightStartText)")
                .foregroundStyle(.secondary)
            Text("Ende: \(flightEndText)")
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            locationsView
            if booking.bookingType == .hotel {
                hotelDateView
            } else {
                flightDateView
            }
        }
    }
}

private struct BookingDetailIOSRateDetailsView: View {
    let rate: SDBookingRateDetails
    let booking: SDBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let amount = rate.totalPriceAmount {
                Text("Preis: \(Formatting.formatCurrencyAmount(amount, currencyCode: rate.totalPriceCurrency))")
                    .foregroundStyle(.secondary)
            }
            if let currency = rate.totalPriceCurrency, !currency.isEmpty {
                Text("Währung: \(currency)")
                    .foregroundStyle(.secondary)
            }
            if rate.roomItems.isEmpty, let room = rate.roomCategory, !room.isEmpty {
                Text("Zimmerkategorie: \(room)")
                    .foregroundStyle(.secondary)
            }
            if let breakfast = rate.includedBreakfast {
                Text("Frühstück: \(breakfast ? "ja" : "nein")")
                    .foregroundStyle(.secondary)
            }
            if let guests = rate.guestCount {
                Text("Gäste: \(guests)")
                    .foregroundStyle(.secondary)
            }
            if let rooms = rate.roomCount {
                Text("Zimmer: \(rooms)")
                    .foregroundStyle(.secondary)
            }
            if let airline = rate.airline, !airline.isEmpty {
                Text("Airline: \(airline)")
                    .foregroundStyle(.secondary)
            }

            if !booking.passengers.isEmpty {
                let names = booking.passengers.compactMap { pax -> String? in
                    let parts = [pax.givenName, pax.familyName].compactMap { part -> String? in
                        guard let part else { return nil }
                        let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    let fullName = parts.joined(separator: " ")
                    return fullName.isEmpty ? nil : fullName
                }
                Text("Passagiere: \(names.joined(separator: ", "))")
                    .foregroundStyle(.secondary)
            } else if let passengers = rate.passengerCount {
                Text("Passagiere: \(passengers)")
                    .foregroundStyle(.secondary)
            }

            if let baggage = rate.baggageInfoRaw, !baggage.isEmpty {
                Text("Gepäck: \(baggage)")
                    .foregroundStyle(.secondary)
            }

            if let rawBoardType = rate.boardTypeRaw,
               !rawBoardType.isEmpty,
               let boardType = BookingBoardType(rawValue: rawBoardType),
               let boardLabel = localizedBoardLabel(for: boardType) {
                Text("Verpflegung: \(boardLabel)")
                    .foregroundStyle(.secondary)
            }

            if let parsed = rate.lastParsedAt {
                Text("Tarif gelesen: \(parsed.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
    }

    private func localizedBoardLabel(for boardType: BookingBoardType) -> String? {
        switch boardType {
        case .roomOnly: return "Nur Zimmer"
        case .breakfastIncluded: return "Frühstück"
        case .halfBoard: return "Halbpension"
        case .fullBoard: return "Vollpension"
        case .unknown: return nil
        }
    }
}

private struct BookingDetailIOSRoomItemsView: View {
    let rate: SDBookingRateDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rate.roomItems.sorted(by: { ($0.sortIndex ?? 0) < ($1.sortIndex ?? 0) })) { item in
                VStack(alignment: .leading, spacing: 4) {
                    if let category = item.category, !category.isEmpty {
                        Text(category)
                            .font(.caption.weight(.medium))
                    }
                    if let code = item.confirmationCode, !code.isEmpty {
                        Text("Buchungsnr.: \(code)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let guest = item.guestSummary, !guest.isEmpty {
                        Text(guest)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let amount = item.priceAmount {
                        let currency = item.priceCurrency ?? rate.totalPriceCurrency
                        Text("Einzelpreis: \(Formatting.formatCurrencyAmount(amount, currencyCode: currency))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct BookingDetailIOSCancellationDeadlinesView: View {
    let booking: SDBooking
    let hotelTimeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(
                booking.cancellationDeadlines.sorted(by: { $0.deadlineAt < $1.deadlineAt }),
                id: \.id
            ) { deadline in
                let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? hotelTimeZone
                VStack(alignment: .leading, spacing: 6) {
                    Text(Formatting.formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M.yyyy HH:mm", timeZone: tz))
                        .font(.caption.weight(.medium))

                    HStack(spacing: 8) {
                        Text(deadline.isFreeCancellation ? "Kostenlos" : "Kostenpflichtig")
                            .font(.caption2)
                            .foregroundStyle(deadline.isFreeCancellation ? .green : .secondary)

                        if let fee = deadline.cancellationFeeAmount {
                            Text(Formatting.formatCurrencyAmount(fee, currencyCode: booking.rateDetails?.totalPriceCurrency))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if deadline.isStrict {
                            Text("strikt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let policy = deadline.policyText, !policy.isEmpty {
                        Text(policy)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct TripDetailIOS: View {
    let tripID: UUID

    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [SDTrip]
    @State private var tripToEdit: SDTrip?

    var trip: SDTrip? {
        trips.first(where: { $0.id == tripID })
    }

    var body: some View {
        Group {
            if let trip {
                NavigationStack {
                    List {
                        Section("Übersicht") {
                            Text(trip.title)
                            Text("Zeitraum: \(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundStyle(.secondary)
                            if let destination = trip.destination, !destination.isEmpty {
                                Text(destination)
                            }
                        }

                        Section("Buchungen") {
                            ForEach(trip.bookings) { booking in
                                NavigationLink(destination: BookingDetailIOS(bookingID: booking.id)) {
                                    OpenBookingRow(booking: booking)
                                }
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Bearbeiten") {
                                tripToEdit = trip
                            }
                            .help("Diese Reise bearbeiten")
                        }
                    }
                    .sheet(item: $tripToEdit) { trip in
                        TripEditorSheet(
                            mode: .edit,
                            trip: trip
                        )
                    }
                }
                .navigationTitle(trip.title)
            } else {
                ContentUnavailableView("Reise nicht gefunden.", systemImage: "magnifyingglass")
            }
        }
    }
}

private struct SyncTab: View {
    @Binding var isShowingSettings: Bool
    @Binding var sessionChromeEpoch: Int

    @Environment(\.syncStore) private var syncStore
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.providerSessionHub) private var sessionHub

    @AppStorage(AppSettingsKeys.notificationEnabled) private var notificationEnabled: Bool = true
    @AppStorage(AppSettingsKeys.eventKitEnabled) private var eventKitEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTripTimesEnabled) private var calendarTripTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarFlightTimesEnabled) private var calendarFlightTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarHotelStaysEnabled) private var calendarHotelStaysEnabled: Bool = false

    @State private var selectedProviderID: ProviderID = .check24
    @State private var webView: WKWebView?
    @State private var isBrowserExpanded = false
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Picker("Provider", selection: $selectedProviderID) {
                            ForEach(iosSyncProviderIDs, id: \.self) { id in
                                Text(providerName(for: id)).tag(id)
                            }
                        }
                        .pickerStyle(.segmented)
                        // Segmented Picker nicht künstlich strecken: sonst wirkt er optisch "zentriert".
                        .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.bar)

                sessionBanner
                Divider()

                WebViewHost(
                    loginURL: loginURLForSelectedProvider(),
                    providerID: selectedProviderID,
                    webView: $webView,
                    onDidFinish: { finishedWebView in
                        handleWebDidFinish(finishedWebView)
                    }
                )
                // Neu-erzeugen beim Ein-/Ausblenden sorgt dafür, dass der loginURL frisch geladen wird.
                .id(isBrowserExpanded)
                .opacity(isBrowserExpanded ? 1 : 0)
                .frame(height: isBrowserExpanded ? 420 : 1)
                .clipped()
                .allowsHitTesting(isBrowserExpanded)

                actionBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Sync")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Neue Reise anlegen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    GlobalChromeTrailingToolbar(
                        isShowingSettings: $isShowingSettings,
                        sessionChromeEpoch: $sessionChromeEpoch
                    )
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                TripEditorSheet(
                    mode: .create,
                    onSaved: { _ in
                        // Auf „Sync“ nicht automatisch navigieren — nur Header/Tab konsistent halten.
                    }
                )
            }
            .onAppear {
                guard let sessionHub else { return }
                sessionHub.syncEnabledProviders(Set(iosSyncProviderIDs))
                // Tab-Wechsel / onAppear darf einen bereits erkannten Session-Status nicht zurücksetzen.
            }
            .onChange(of: selectedProviderID) { _, newProviderID in
                guard let sessionHub else { return }
                // Provider-Wechsel darf eine bereits erkannte Session nicht downgraden.
                if sessionHub.status(for: newProviderID) != .sessionReady {
                    sessionHub.updateStatus(newProviderID, status: .needsLogin)
                }
            }
        }
    }

    private func providerName(for id: ProviderID) -> String {
        providerRegistry?.providers.first(where: { $0.id == id })?.displayName ?? id.rawValue
    }

    private var sessionStatus: ProviderSessionStatus {
        _ = sessionChromeEpoch
        return sessionHub?.status(for: selectedProviderID) ?? .needsLogin
    }

    private var lastURLString: String? {
        _ = sessionChromeEpoch
        return sessionHub?.lastURLString(for: selectedProviderID)
    }

    private var canStartSync: Bool {
        guard let syncStore else { return false }
        let targetWebView = webView ?? sessionHub?.webView(for: selectedProviderID)
        guard targetWebView != nil else { return false }
        guard syncStore.isSyncing != true else { return false }
        return sessionStatus == .sessionReady
    }

    private var syncAllSettings: AppSettings {
        AppSettings(
            notificationEnabled: notificationEnabled,
            eventKitEnabled: eventKitEnabled,
            calendarTripTimesEnabled: calendarTripTimesEnabled,
            calendarFlightTimesEnabled: calendarFlightTimesEnabled,
            calendarHotelStaysEnabled: calendarHotelStaysEnabled
        )
    }

    private func loginURLForSelectedProvider() -> URL? {
        let provider = providerRegistry?.provider(id: selectedProviderID)
        let loginConfig = provider as? any TravelProviderLoginConfiguration
        return loginConfig?.loginURL
    }

    private var sessionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: sessionStatus == .sessionReady
                  ? "checkmark.circle.fill"
                  : "person.crop.circle.badge.questionmark")
            .foregroundStyle(sessionStatus == .sessionReady ? .green : .secondary)
            .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(sessionStatus == .sessionReady ? "Angemeldet" : "Anmeldung erforderlich")
                    .font(.headline)
                Text(sessionStatus == .sessionReady
                     ? "Du kannst jetzt die Buchungen synchronisieren."
                     : "Melde dich im Browser unten beim Provider an (inkl. 2FA falls nötig).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let lastURLString {
                Text(lastURLString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 280, alignment: .trailing)
                    .textSelection(.enabled)
                    .help(lastURLString)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let statusMessage = syncStore?.statusMessage {
                Text(statusMessage).foregroundStyle(.secondary)
            }
            if let errorMessage = syncStore?.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            Text(sessionStatus == .sessionReady
                 ? "Nach dem Login synchronisiert die App Aktivitäten und Stornofristen lokal."
                 : "Sync ist deaktiviert, bis die Session bereit ist.")
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    isBrowserExpanded.toggle()
                } label: {
                    Label(
                        isBrowserExpanded ? "Browser ausblenden" : "Browser anzeigen",
                        systemImage: isBrowserExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    isBrowserExpanded = true
                } label: {
                    Text("Login")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isBrowserExpanded)
            }

            HStack(spacing: 12) {
                Button {
                    guard let syncStore else { return }
                    let targetWebView = webView ?? sessionHub?.webView(for: selectedProviderID)
                    guard let targetWebView else { return }
                    Task {
                        await syncStore.sync(
                            providerID: selectedProviderID,
                            webView: targetWebView,
                            settings: syncAllSettings
                        )
                    }
                } label: {
                    if syncStore?.isSyncing == true, syncStore?.syncingProviderID == selectedProviderID {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Jetzt synchronisieren")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canStartSync)
                .help(canStartSync
                    ? "Aktivitäten und Stornofristen dieses Providers lokal aktualisieren"
                    : "Sync nicht möglich — Anmeldung und aktiven Provider prüfen")
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(.bar)
    }

    @MainActor
    private func handleWebDidFinish(_ finishedWebView: WKWebView) {
        guard let hub = sessionHub else { return }
        guard let url = finishedWebView.url else { return }

        hub.syncEnabledProviders(Set(iosSyncProviderIDs))
        let heuristic = ProviderSessionStatusResolver.classify(url)

        hub.updateLastURL(selectedProviderID, urlString: url.absoluteString)
        hub.updateWebView(selectedProviderID, webView: finishedWebView)

        switch heuristic {
        case .sessionReady:
            hub.updateStatus(selectedProviderID, status: .sessionReady)
        case .needsLogin:
            // Wenn bereits `sessionReady` erkannt wurde, darf ein späterer Login-Look nicht downgraden.
            if hub.status(for: selectedProviderID) != .sessionReady {
                hub.updateStatus(selectedProviderID, status: .needsLogin)
            }
        case .shouldProbeOpodo:
            // Opodo: Heuristik ist oft unklar → GraphQL Probe nach Navigation.
            if hub.status(for: selectedProviderID) != .sessionReady {
                hub.updateStatus(selectedProviderID, status: .needsLogin)
            }
            Task {
                do {
                    let text = try await finishedWebView.fetchAuthenticatedText(
                        url: OpodoSessionProbe.graphqlURL,
                        method: "POST",
                        accept: "application/json",
                        referer: "https://www.opodo.de/",
                        contentType: "application/json",
                        body: OpodoSessionProbe.getUserAccountRequestBody()
                    )
                    if let loggedIn = OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: text) {
                        await MainActor.run {
                            if loggedIn {
                                hub.updateStatus(selectedProviderID, status: .sessionReady)
                            } else if hub.status(for: selectedProviderID) != .sessionReady {
                                hub.updateStatus(selectedProviderID, status: .needsLogin)
                            }
                            sessionChromeEpoch &+= 1
                        }
                    }
                } catch {
                    // Probe fehlgeschlagen: Status bleibt konservativ `needsLogin`.
                }
            }
        case .unknown:
            // `unknown` darf eine bereits erkannte Session nicht downgraden.
            if hub.status(for: selectedProviderID) != .sessionReady {
                hub.updateStatus(selectedProviderID, status: .needsLogin)
            }
        }

        sessionChromeEpoch &+= 1
    }
}

private struct WebViewHost: View {
    let loginURL: URL?
    let providerID: ProviderID
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    var body: some View {
        ProviderSessionWebView(
            loginURL: loginURL,
            webView: $webView,
            onDidFinish: onDidFinish
        )
    }
}

#if canImport(UIKit)
import UIKit

private struct ProviderSessionWebView: UIViewRepresentable {
    let loginURL: URL?
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidFinish: onDidFinish)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        webView = view
        context.coordinator.loadedLoginURL = loginURL
        if let loginURL { view.load(URLRequest(url: loginURL)) }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let loginURL else { return }
        if context.coordinator.loadedLoginURL != loginURL {
            context.coordinator.loadedLoginURL = loginURL
            uiView.load(URLRequest(url: loginURL))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onDidFinish: (WKWebView) -> Void
        var loadedLoginURL: URL?

        init(onDidFinish: @escaping (WKWebView) -> Void) {
            self.onDidFinish = onDidFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onDidFinish(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // SSOT-ähnlich zu ProviderSessionView: Session-Heuristik auch bei Redirect/Commit aktualisieren.
            onDidFinish(webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            // Wenn die Navigation scheitert, bleibt meist der aktuelle URL-Stand für eine Heuristik relevant.
            onDidFinish(webView)
        }
    }
}
#else
import AppKit

private struct ProviderSessionWebView: NSViewRepresentable {
    let loginURL: URL?
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        webView = view
        context.coordinator.loadedLoginURL = loginURL
        if let loginURL { view.load(URLRequest(url: loginURL)) }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let loginURL else { return }
        if context.coordinator.loadedLoginURL != loginURL {
            context.coordinator.loadedLoginURL = loginURL
            nsView.load(URLRequest(url: loginURL))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidFinish: onDidFinish)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onDidFinish: (WKWebView) -> Void
        var loadedLoginURL: URL?

        init(onDidFinish: @escaping (WKWebView) -> Void) {
            self.onDidFinish = onDidFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onDidFinish(webView)
        }
    }
}
#endif

