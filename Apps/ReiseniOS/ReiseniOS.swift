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

private struct RootTabView: View {
    @ViewBuilder
    var body: some View {
        if #available(iOS 18.0, *) {
            tabs
                .tabViewStyle(.sidebarAdaptable)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView {
            ReisenTab()
                .tabItem {
                    Label("Reisen", systemImage: "airplane")
                }

            OffenTab()
                .tabItem {
                    Label("Offen", systemImage: "list.bullet.rectangle")
                }

            SyncTab()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }

            SettingsTab()
                .tabItem {
                    Label("Mehr", systemImage: "gearshape")
                }
        }
    }
}

private struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Mehr")
        }
    }
}

private struct ReisenTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    NavigationLink(value: trip.id) {
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
            .navigationDestination(for: UUID.self) { tripID in
                TripDetailIOS(tripID: tripID)
            }
        }
    }
}

private struct OffenTab: View {
    var body: some View {
        OpenBookingsScreen()
    }
}

private struct OpenBookingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]

    @State private var assignErrorMessage: String?
    @State private var showAssignError = false

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
        NavigationStack {
            if openBookings.isEmpty {
                ContentUnavailableView(
                    "Keine offenen Buchungen",
                    systemImage: "calendar",
                    description: Text("Aktuell gibt es keine Buchungen, die noch keiner Reise zugeordnet sind.")
                )
                .navigationTitle("Offen")
            } else {
                List(openBookings, id: \.id) { booking in
                    NavigationLink(value: booking.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                                .lineLimit(1)
                                .font(.headline)
                            Text("\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Offen")
                .navigationDestination(for: UUID.self) { bookingID in
                    OpenBookingDetailIOS(
                        bookingID: bookingID,
                        trips: trips
                    )
                }
            }
        }
    }
}

private struct OpenBookingDetailIOS: View {
    let bookingID: UUID
    let trips: [SDTrip]

    @Environment(\.modelContext) private var modelContext
    @Query private var bookings: [SDBooking]

    @State private var assignErrorMessage: String?
    @State private var showAssignError = false

    private var booking: SDBooking? {
        bookings.first(where: { $0.id == bookingID })
    }

    private func isOpenBookingCandidate(
        _ booking: SDBooking,
        for trip: SDTrip,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard booking.trip == nil, booking.status != .cancelled else { return false }
        let startOfToday = calendar.startOfDay(for: now)
        let tripStartDay = calendar.startOfDay(for: trip.startDate)
        let tripEndDay = calendar.startOfDay(for: trip.endDate)
        let bookingStartDay = calendar.startOfDay(for: booking.startAt)
        let bookingEndDay = calendar.startOfDay(for: booking.endAt)
        return bookingStartDay >= startOfToday
            && bookingStartDay >= tripStartDay
            && bookingEndDay <= tripEndDay
    }

    private var matchingTrip: SDTrip? {
        guard let booking else { return nil }
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

    var body: some View {
        Group {
            if let booking {
                List {
                    Section("Übersicht") {
                        Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                            .font(.headline)
                        Text("Zeitraum: \(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(.secondary)
                        if let code = booking.confirmationCode, !code.isEmpty {
                            Text("Bestätigung: \(code)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Zuordnung") {
                        if let trip = matchingTrip {
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
                        } else {
                            Text("Keine passende Reise gefunden.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Links") {
                        if let externalURL {
                            Link("Im Browser öffnen", destination: externalURL)
                        } else {
                            Text("Kein Browser-Link verfügbar.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle(booking.title ?? booking.bookingType.rawValue.capitalized)
                .alert(
                    "Zuordnung fehlgeschlagen",
                    isPresented: $showAssignError
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(assignErrorMessage ?? "")
                }
            } else {
                ContentUnavailableView(
                    "Buchung nicht gefunden",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Die ausgewählte Buchung ist nicht mehr verfügbar.")
                )
            }
        }
    }
}

private struct TripDetailIOS: View {
    let tripID: UUID

    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [SDTrip]

    var trip: SDTrip? {
        trips.first(where: { $0.id == tripID })
    }

    var body: some View {
        Group {
            if let trip {
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(booking.title ?? booking.providerRaw)
                                    .font(.headline)
                                Text("\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $selectedProviderID) {
                        ForEach(providerIDs, id: \.self) { id in
                            Text(providerName(for: id)).tag(id)
                        }
                    }

                    Button("Login & Session im WebView öffnen") {
                        if let sessionHub { sessionHub.updateWebView(selectedProviderID, webView: webView) }
                    }
                }

                Section("Sync") {
                    Button("Jetzt synchronisieren") {
                        guard let syncStore else { return }
                        guard let webView else { return }
                        let settings = AppSettings(
                            notificationEnabled: notificationEnabled,
                            eventKitEnabled: eventKitEnabled,
                            calendarTripTimesEnabled: calendarTripTimesEnabled,
                            calendarFlightTimesEnabled: calendarFlightTimesEnabled,
                            calendarHotelStaysEnabled: calendarHotelStaysEnabled
                        )
                        Task {
                            await syncStore.sync(providerID: selectedProviderID, webView: webView, settings: settings)
                        }
                    }

                    if let statusMessage = syncStore?.statusMessage {
                        Text(statusMessage).foregroundStyle(.secondary)
                    }
                    if let errorMessage = syncStore?.errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sync")
            .safeAreaInset(edge: .bottom) {
                WebViewHost(
                    loginURL: loginURLForSelectedProvider(),
                    providerID: selectedProviderID,
                    webView: $webView,
                    onDidFinish: {
                        guard let sessionHub else { return }
                        sessionHub.updateStatus(selectedProviderID, status: .sessionReady)
                        sessionHub.updateLastURL(selectedProviderID, urlString: webView?.url?.absoluteString)
                    }
                )
                .frame(maxWidth: .infinity, minHeight: 420)
            }
        }
    }

    private var providerIDs: [ProviderID] { [.check24, .opodo, .booking, .airbnb] }

    private func providerName(for id: ProviderID) -> String {
        providerRegistry?.providers.first(where: { $0.id == id })?.displayName ?? id.rawValue
    }

    private func loginURLForSelectedProvider() -> URL? {
        let provider = providerRegistry?.provider(id: selectedProviderID)
        let loginConfig = provider as? any TravelProviderLoginConfiguration
        return loginConfig?.loginURL
    }
}

private struct WebViewHost: View {
    let loginURL: URL?
    let providerID: ProviderID
    @Binding var webView: WKWebView?
    let onDidFinish: () -> Void

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
    let onDidFinish: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        webView = view
        if let loginURL {
            view.load(URLRequest(url: loginURL))
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Keep behavior deterministic: only reload if no content yet.
        guard uiView.url == nil, let loginURL else { return }
        uiView.load(URLRequest(url: loginURL))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidFinish: onDidFinish)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onDidFinish: () -> Void

        init(onDidFinish: @escaping () -> Void) {
            self.onDidFinish = onDidFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onDidFinish()
        }
    }
}
#else
import AppKit

private struct ProviderSessionWebView: NSViewRepresentable {
    let loginURL: URL?
    @Binding var webView: WKWebView?
    let onDidFinish: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        webView = view
        if let loginURL {
            view.load(URLRequest(url: loginURL))
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Keep behavior deterministic: only reload if no content yet.
        guard nsView.url == nil, let loginURL else { return }
        nsView.load(URLRequest(url: loginURL))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidFinish: onDidFinish)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onDidFinish: () -> Void

        init(onDidFinish: @escaping () -> Void) {
            self.onDidFinish = onDidFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onDidFinish()
        }
    }
}
#endif

