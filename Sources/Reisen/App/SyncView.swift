import SwiftUI
import WebKit
import SwiftData
import AppKit
import ReisenDomain
import ReisenData
import ReisenProviders

/// Provider-Login und Sync als primäre Inhaltsfläche (kein Sheet).
struct SyncView: View {
    let providerID: ProviderID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.syncStore) private var store
    @Environment(\.providerSessionHub) private var sessionHub

    @AppStorage(AppSettingsKeys.notificationEnabled) private var notificationEnabled: Bool = true
    @AppStorage(AppSettingsKeys.eventKitEnabled) private var eventKitEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitle) private var calendarTitle: String = "Reisen"
    @AppStorage(AppSettingsKeys.reminderCalendarTitle) private var reminderCalendarTitle: String = "Reisen"
    @AppStorage(AppSettingsKeys.eventCalendarCreateIfMissing) private var eventCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.reminderCalendarCreateIfMissing) private var reminderCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.leadTimesDays) private var leadTimesDaysRaw: String = "7,3,1"
    @AppStorage(AppSettingsKeys.calendarTripTimesEnabled) private var calendarTripTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarFlightTimesEnabled) private var calendarFlightTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarHotelStaysEnabled) private var calendarHotelStaysEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitleMode) private var calendarTitleModeRaw: String = CalendarTitleMode.tripTitle.rawValue
    @AppStorage private var isProviderEnabled: Bool
    @AppStorage private var preferredKeychainAccountID: String

    @State private var sessionWebView: WKWebView?
    @State private var sessionStatus: ProviderSessionStatus = .needsLogin
    @State private var lastURLString: String?
    @State private var missingProviderMessage: String?
    @State private var isBrowserExpanded = false
    @State private var keychainAccounts: [KeychainCredentialAccount] = []
    @State private var selectedKeychainAccount: KeychainCredentialAccount?
    @State private var autofillCredentials: ProviderCredentials?
    @State private var keychainMessage: String?
    @State private var isSaveCredentialSheetPresented = false
    /// Keychain erst nach Cookie-/Session-Probe laden — sonst Dialog trotz gültiger Cookies.
    @State private var keychainReloadTask: Task<Void, Never>?

    init(providerID: ProviderID) {
        self.providerID = providerID
        self._isProviderEnabled = AppStorage(
            wrappedValue: true,
            AppSettingsKeys.providerEnabledKey(for: providerID)
        )
        self._preferredKeychainAccountID = AppStorage(
            wrappedValue: "",
            AppSettingsKeys.preferredKeychainAccountKey(for: providerID)
        )
    }

    private var settings: AppSettings {
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

    private var compositionErrorMessage: String? {
        if providerRegistry == nil {
            return "Provider-Registry fehlt in der App-Composition."
        }
        if store == nil {
            return "SyncStore fehlt in der App-Composition."
        }
        return nil
    }

    private var canSync: Bool {
        isProviderEnabled
            && sessionWebView != nil
            && providerRegistry != nil
            && store != nil
            && !(store?.isSyncing ?? false)
    }

    private var loginConfiguration: (any TravelProviderLoginConfiguration)? {
        providerRegistry?.provider(id: providerID) as? TravelProviderLoginConfiguration
    }

    private var providerLoginURL: URL? {
        loginConfiguration?.loginURL
    }

    private var keychainServerHost: String? {
        loginConfiguration?.keychainServerHost
    }

    private var canStartSync: Bool {
        canSync
            && missingProviderMessage == nil
            && compositionErrorMessage == nil
    }

    private var canInsertKeychainCredentials: Bool {
        selectedKeychainAccount != nil && sessionWebView != nil
    }

    /// Status/Fehler nur für den Provider anzeigen, der sie erzeugt hat.
    private var storeMessageBelongsToThisProvider: Bool {
        guard let store else { return false }
        if store.isSyncing {
            return store.syncingProviderID == providerID
        }
        return store.messageProviderID == providerID
    }

    /// Hub zuerst — sonst erzeugt `makeNSView` vor `onAppear` ein zweites WebView.
    private var webViewBinding: Binding<WKWebView?> {
        Binding(
            get: {
                if let sessionWebView { return sessionWebView }
                return sessionHub?.webView(for: providerID)
            },
            set: { newValue in
                sessionWebView = newValue
                sessionHub?.updateWebView(providerID, webView: newValue)
            }
        )
    }

    var body: some View {
        Group {
            if !isProviderEnabled {
                ContentUnavailableView(
                    "Provider deaktiviert",
                    systemImage: "nosign",
                    description: Text("Aktiviere den Provider über die Checkbox in der Seitenleiste.")
                )
            } else {
                VStack(spacing: 0) {
                    sessionBanner
                    Divider()
                    ProviderSessionView(
                        loginURL: providerLoginURL,
                        sessionStatus: $sessionStatus,
                        lastURLString: $lastURLString,
                        webView: webViewBinding,
                        autofillCredentials: autofillCredentials
                    )
                    .frame(
                        maxWidth: .infinity,
                        // Wenn Browser nicht benötigt wird, soll er im Layout kollabieren.
                        minHeight: isBrowserExpanded ? 120 : 0,
                        maxHeight: isBrowserExpanded ? .infinity : 0,
                        alignment: .top
                    )
                    .opacity(isBrowserExpanded ? 1 : 0)
                    .allowsHitTesting(isBrowserExpanded)
                    .accessibilityHidden(!isBrowserExpanded)
                    .clipped()

                    Divider()
                    actionBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Provider Sync")
        .sheet(isPresented: $isSaveCredentialSheetPresented) {
            if let keychainServerHost {
                SaveProviderCredentialSheet(serverHost: keychainServerHost) { account in
                    preferredKeychainAccountID = account.id
                    reloadKeychainAccounts(selecting: account)
                }
            }
        }
        .onAppear {
            restoreSessionFromHub()
            // Browser nur bei Login-Bedarf; sonst Sync-UI ohne Webseite.
            isBrowserExpanded = (sessionStatus == .needsLogin)
            validateProviderAvailability()
            if sessionStatus == .needsLogin {
                scheduleKeychainReloadIfLoginStillRequired()
            } else {
                clearKeychainRuntimeState()
            }
            publishSessionToHub()

            Task { @MainActor in
                guard sessionStatus == .needsLogin else { return }
                let timeoutNanoseconds: UInt64 = 10_000_000_000
                let pollNanoseconds: UInt64 = 500_000_000
                let start = DispatchTime.now().uptimeNanoseconds

                while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
                    if sessionHub?.status(for: providerID) == .sessionReady {
                        sessionStatus = .sessionReady
                        isBrowserExpanded = false
                        clearKeychainRuntimeState()
                        break
                    }
                    try? await Task.sleep(nanoseconds: pollNanoseconds)
                }
            }
        }
        .onDisappear {
            store?.dismissMessages(for: providerID)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard sessionStatus == .needsLogin else { return }
            scheduleKeychainReloadIfLoginStillRequired()
        }
        .onChange(of: sessionStatus) { _, newValue in
            sessionHub?.updateStatus(providerID, status: newValue)
            switch newValue {
            case .needsLogin:
                isBrowserExpanded = true
                scheduleKeychainReloadIfLoginStillRequired()
            case .sessionReady:
                isBrowserExpanded = false
                clearKeychainRuntimeState()
            }
        }
        .onChange(of: lastURLString) { _, newValue in
            sessionHub?.updateLastURL(providerID, urlString: newValue)
            // Keychain hier nicht anfassen — Redirects (Check24 SSO) sehen kurz wie Login aus,
            // obwohl Cookies danach sessionReady setzen. Keychain nur über den Settle-Pfad.
        }
        .onChange(of: sessionWebView != nil) { _, _ in
            sessionHub?.updateWebView(providerID, webView: sessionWebView)
        }
        .onReceive(NotificationCenter.default.publisher(for: .reisenSyncCurrentProvider)) { _ in
            Task { await runSync() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store?.isSyncing == true {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    Task { await runSync() }
                } label: {
                    Label("Buchungen synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!canSync)
                .help(canSync
                    ? "Buchungen dieses Providers jetzt synchronisieren"
                    : "Sync nicht möglich — Anmeldung und aktiven Provider prüfen")
            }
        }
    }

    private func publishSessionToHub() {
        sessionHub?.updateStatus(providerID, status: sessionStatus)
        sessionHub?.updateLastURL(providerID, urlString: lastURLString)
        sessionHub?.updateWebView(providerID, webView: sessionWebView)
    }

    private func restoreSessionFromHub() {
        guard let sessionHub else { return }
        if let status = sessionHub.status(for: providerID) {
            sessionStatus = status
        }
        if let url = sessionHub.lastURLString(for: providerID) {
            lastURLString = url
        }
        if let webView = sessionHub.webView(for: providerID) {
            sessionWebView = webView
        }
    }

    private var sessionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: sessionStatus == .sessionReady ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
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

            if sessionStatus == .needsLogin {
                credentialControls
            }

            if let lastURLString {
                // SwiftUI-Text statt NSTextView: CopyableTextView blähte die Banner-Höhe auf
                // und schnitt dadurch „Anmeldung erforderlich“ oben ab.
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    @ViewBuilder
    private var credentialControls: some View {
        HStack(spacing: 8) {
            if keychainAccounts.count > 1 {
                Picker("Konto", selection: selectedAccountBinding) {
                    Text("Konto wählen…").tag(Optional<KeychainCredentialAccount>.none)
                    ForEach(keychainAccounts) { account in
                        Text("\(account.username) (\(account.serverHost))").tag(Optional(account))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                .controlSize(.small)
            } else if let selectedKeychainAccount {
                Text(selectedKeychainAccount.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("\(selectedKeychainAccount.username) @ \(selectedKeychainAccount.serverHost)")
            }

            Button {
                insertKeychainCredentials()
            } label: {
                Label("Ausfüllen", systemImage: "key.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canInsertKeychainCredentials)
            .help(
                canInsertKeychainCredentials
                    ? "E-Mail und Kennwort des gewählten Kontos in die Login-Felder einfügen."
                    : (keychainMessage ?? "Kein Konto ausgewählt.")
            )

            Button {
                isSaveCredentialSheetPresented = true
            } label: {
                Label("Konto speichern…", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(keychainServerHost == nil)
            .help("Konto aus Passwords hier speichern — Hauptweg, weil Passwords-App-Einträge für Apps gesperrt sind.")
        }
    }

    private var selectedAccountBinding: Binding<KeychainCredentialAccount?> {
        Binding(
            get: { selectedKeychainAccount },
            set: { newValue in
                selectAccount(newValue)
            }
        )
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let compositionErrorMessage {
                CopyableLabel(
                    title: compositionErrorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    textStyle: .callout,
                    textColor: .systemRed,
                    iconColor: .red
                )
            } else if let missingProviderMessage {
                CopyableLabel(
                    title: missingProviderMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    textStyle: .callout,
                    textColor: .systemRed,
                    iconColor: .red
                )
            } else if let errorMessage = store?.errorMessage, storeMessageBelongsToThisProvider {
                CopyableLabel(
                    title: errorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    textStyle: .callout,
                    textColor: .systemRed,
                    iconColor: .red
                )
            } else if let statusMessage = store?.statusMessage, storeMessageBelongsToThisProvider {
                CopyableLabel(
                    title: statusMessage,
                    systemImage: "checkmark.circle",
                    textStyle: .callout,
                    textColor: .secondaryLabelColor,
                    iconColor: .secondary
                )
            } else if sessionStatus == .needsLogin, let keychainMessage {
                VStack(alignment: .leading, spacing: 8) {
                    CopyableLabel(
                        title: keychainMessage,
                        systemImage: "key.slash",
                        textStyle: .callout,
                        textColor: .secondaryLabelColor,
                        iconColor: .secondary
                    )
                    HStack(spacing: 8) {
                        Button {
                            isSaveCredentialSheetPresented = true
                        } label: {
                            Label("Konto speichern…", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(keychainServerHost == nil)

                        Button {
                            if !MacSystemApps.openPasswords() {
                                appendKeychainMessage("Passwords-App wurde nicht gefunden.")
                            }
                        } label: {
                            Label("Passwords öffnen", systemImage: "key.horizontal")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            if !MacSystemApps.openKeychainAccess() {
                                appendKeychainMessage("Schlüsselbundverwaltung wurde nicht gefunden.")
                            }
                        } label: {
                            Label("Schlüsselbundverwaltung", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            HStack {
                Text("Nach dem Login synchronisiert die App Aktivitäten und Stornofristen lokal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
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
                .help(isBrowserExpanded
                    ? "Eingebetteten Browser ausblenden"
                    : "Eingebetteten Browser anzeigen")

                Button {
                    Task { await runSync() }
                } label: {
                    if store?.isSyncing == true {
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
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .background(.bar)
    }

    @MainActor
    private func runSync() async {
        guard let sessionWebView else { return }
        guard let store else { return }
        await store.sync(
            providerID: providerID,
            webView: sessionWebView,
            settings: settings
        )
    }

    private func validateProviderAvailability() {
        missingProviderMessage = nil
        guard let providerRegistry else {
            return
        }
        guard providerRegistry.provider(id: providerID) != nil else {
            missingProviderMessage = "Provider \(providerID.rawValue) ist nicht verfügbar."
            return
        }
        guard providerLoginURL != nil else {
            missingProviderMessage = "Login-Metadaten fehlen für Provider \(providerID.rawValue)."
            return
        }
    }

    /// Keychain erst nach Cookie-/Session-Probe — sonst Dialog trotz gültiger Cookies.
    /// Wenn Login bestätigt nötig: Konten laden und automatisch ausfüllen/submitten.
    private func scheduleKeychainReloadIfLoginStillRequired() {
        keychainReloadTask?.cancel()
        keychainReloadTask = Task { @MainActor in
            // Opodo-Probe ~0.45s + Netzwerk; Check24-SSO-Redirects brauchen oft länger.
            // Wenn der Startup-Probe bereits eine Login-URL gesetzt hat, kürzer warten.
            let urlAlreadyLogin = AuthPageURLHeuristic.looksLikeLoginPage(
                (lastURLString ?? sessionHub?.lastURLString(for: providerID) ?? "").lowercased()
            )
            let settleNanoseconds: UInt64 = urlAlreadyLogin ? 400_000_000 : 1_500_000_000
            let pollNanoseconds: UInt64 = 150_000_000
            let start = DispatchTime.now().uptimeNanoseconds

            while DispatchTime.now().uptimeNanoseconds - start < settleNanoseconds {
                guard !Task.isCancelled else { return }
                if sessionStatus == .sessionReady {
                    return
                }
                if sessionHub?.status(for: providerID) == .sessionReady {
                    sessionStatus = .sessionReady
                    clearKeychainRuntimeState()
                    return
                }
                try? await Task.sleep(nanoseconds: pollNanoseconds)
            }

            guard !Task.isCancelled else { return }
            guard sessionStatus == .needsLogin else { return }

            // Cookies haben versagt → Keychain + Auto-Login.
            reloadKeychainAccounts(autoFill: true)
        }
    }

    private func clearKeychainRuntimeState() {
        keychainReloadTask?.cancel()
        keychainReloadTask = nil
        autofillCredentials = nil
        keychainAccounts = []
        selectedKeychainAccount = nil
        keychainMessage = nil
    }

    private func reloadKeychainAccounts(
        selecting preferred: KeychainCredentialAccount? = nil,
        autoFill: Bool = false
    ) {
        guard sessionStatus == .needsLogin else { return }

        autofillCredentials = nil
        keychainMessage = nil
        keychainAccounts = []
        selectedKeychainAccount = nil

        guard let host = keychainServerHost else {
            keychainMessage = "Kein Keychain-Host für diesen Provider konfiguriert."
            return
        }

        do {
            let accounts = try KeychainCredentialStore().accounts(serverHost: host)
            keychainAccounts = accounts
            applyAccountSelection(accounts: accounts, preferred: preferred, autoFill: autoFill)
        } catch {
            keychainMessage = error.localizedDescription
        }
    }

    private func applyAccountSelection(
        accounts: [KeychainCredentialAccount],
        preferred: KeychainCredentialAccount?,
        autoFill: Bool = false
    ) {
        if accounts.isEmpty {
            preferredKeychainAccountID = ""
            keychainMessage = KeychainCredentialStore.CredentialStoreError.noEntry(serverHost: keychainServerHost ?? "").errorDescription
            return
        }

        if let preferred, accounts.contains(preferred) {
            selectAccount(preferred, autoFill: autoFill)
            return
        }

        if let stored = accounts.first(where: { $0.id == preferredKeychainAccountID }) {
            selectAccount(stored, autoFill: autoFill)
            return
        }

        if accounts.count == 1 {
            selectAccount(accounts[0], autoFill: autoFill)
            return
        }

        // Mehrere Konten ohne gespeicherte Auswahl: nichts vorauswählen.
        preferredKeychainAccountID = ""
        selectedKeychainAccount = nil
        autofillCredentials = nil
        keychainMessage = """
        \(accounts.count) lesbare Konten für '\(keychainServerHost ?? "")' gefunden.
        Bitte das gewünschte Konto wählen. Fehlt ein Passwords-Konto: „Konto speichern…“.
        """
    }

    private func selectAccount(_ account: KeychainCredentialAccount?, autoFill: Bool = false) {
        selectedKeychainAccount = account
        autofillCredentials = nil
        guard let account else {
            if keychainAccounts.count > 1 {
                keychainMessage = """
                \(keychainAccounts.count) lesbare Konten für '\(keychainServerHost ?? "")' gefunden.
                Bitte das gewünschte Konto wählen. Fehlt ein Passwords-Konto: „Konto speichern…“.
                """
            }
            return
        }

        preferredKeychainAccountID = account.id
        keychainMessage = nil
        if autoFill {
            scheduleAutoFillFromKeychain()
        }
    }

    /// Automatisches Ausfüllen + Submit, wenn Login nötig und Konto bekannt.
    private func scheduleAutoFillFromKeychain() {
        Task { @MainActor in
            for _ in 0..<10 {
                guard sessionStatus == .needsLogin else { return }
                guard selectedKeychainAccount != nil else { return }
                if sessionWebView != nil || sessionHub?.webView(for: providerID) != nil {
                    insertKeychainCredentials()
                    return
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    @MainActor
    private func insertKeychainCredentials() {
        guard let account = selectedKeychainAccount else { return }
        guard let targetWebView = sessionWebView ?? sessionHub?.webView(for: providerID) else { return }
        let credentials: ProviderCredentials
        do {
            credentials = try KeychainCredentialStore().credentials(for: account)
            autofillCredentials = credentials
        } catch {
            autofillCredentials = nil
            keychainMessage = error.localizedDescription
            return
        }
        // Kein LoginFieldHints vor Fill — autocomplete-Mutation brach Opodo PasswordLogin.
        // #region agent log
        AgentDebugLog.write(
            hypothesisId: "S",
            location: "SyncView.swift:insertKeychainCredentials",
            message: "Ausfüllen (pre-submit, no hints)",
            data: [
                "usernameLen": credentials.username.count,
                "url": targetWebView.url?.absoluteString ?? "nil",
            ]
        )
        // #endregion

        let maxAttempts = 3
        let delays: [TimeInterval] = [0.25, 0.75] // wait for DOM to settle between attempts

        var attempt = 0
        func attemptFill() {
            attempt += 1
            LoginAutofill.apply(in: targetWebView, credentials: credentials) { filled in
                // #region agent log
                AgentDebugLog.write(
                    hypothesisId: "S",
                    location: "SyncView.swift:insertKeychainCredentials.callback",
                    message: "Ausfüllen result",
                    data: [
                        "attempt": attempt,
                        "maxAttempts": maxAttempts,
                        "filled": filled,
                    ]
                )
                // #endregion

                guard !filled, attempt < maxAttempts else { return }
                let delay = delays[min(attempt - 1, delays.count - 1)]
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    attemptFill()
                }
            }
        }

        attemptFill()
    }

    private func appendKeychainMessage(_ suffix: String) {
        if let existing = keychainMessage, !existing.isEmpty {
            keychainMessage = existing + "\n\n" + suffix
        } else {
            keychainMessage = suffix
        }
    }
}
