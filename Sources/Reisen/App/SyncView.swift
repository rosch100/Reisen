import SwiftUI
import WebKit
import SwiftData
import AppKit
import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenAppCore
import ReisenProviderSync
import ReisenSharedUI

/// Provider-Login und Sync als primäre Inhaltsfläche (kein Sheet).
struct SyncView: View {
    let providerID: ProviderID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.syncStore) private var store
    @Environment(\.providerSessionHub) private var sessionHub

    @AppStorage(AppSettingsKeys.notificationEnabled) private var notificationEnabled: Bool = true
    @AppStorage(AppSettingsKeys.eventKitEnabled) private var eventKitEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitle) private var calendarTitle: String = "Voyenna"
    @AppStorage(AppSettingsKeys.reminderCalendarTitle) private var reminderCalendarTitle: String = "Voyenna"
    @AppStorage(AppSettingsKeys.eventCalendarCreateIfMissing) private var eventCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.reminderCalendarCreateIfMissing) private var reminderCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.leadTimesDays) private var leadTimesDaysRaw: String = "7,3,1"
    @AppStorage(AppSettingsKeys.calendarTripTimesEnabled) private var calendarTripTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarFlightTimesEnabled) private var calendarFlightTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarHotelStaysEnabled) private var calendarHotelStaysEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitleMode) private var calendarTitleModeRaw: String = CalendarTitleMode.tripTitle.rawValue
    @AppStorage(AppSettingsKeys.rememberLoginAutomatically) private var rememberLoginAutomatically: Bool = false
    @AppStorage private var isProviderEnabled: Bool
    @AppStorage private var preferredKeychainAccountID: String

    @State private var sessionWebView: WKWebView?
    @State private var diagnosticRunID = UUID()
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
    @State private var pendingRememberCredentials: ProviderCredentials?
    @State private var rememberLoginMode: ProviderRememberLoginMode = .passwordManual
    @State private var rememberLoginMessage: String?
    @State private var navigationWasBlocked = false

    init(providerID: ProviderID) {
        self.providerID = providerID
        self._isProviderEnabled = AppStorage(
            wrappedValue: false,
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
            return L10n.string(.syncCompositionRegistryMissing)
        }
        if store == nil {
            return L10n.string(.syncCompositionStoreMissing)
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

    private var isSessionReady: Bool {
        sessionStatus == .sessionReady
    }

    private var browserExpanded: Bool {
        SyncBrowserChrome.isBrowserExpanded(
            isSessionReady: isSessionReady,
            userExpanded: isBrowserExpanded
        )
    }

    private var showsBrowserCollapseControl: Bool {
        SyncBrowserChrome.showsCollapseControl(isSessionReady: isSessionReady)
    }

    var body: some View {
        Group {
            if !isProviderEnabled {
                ContentUnavailableView(
                    L10n.string(.loginStatusGray),
                    systemImage: "nosign",
                    description: Text(L10n.string(.syncProviderDisabledHint))
                )
            } else if UITestingLaunch.isActive {
                VStack(spacing: 0) {
                    sessionBanner
                    Divider()
                    actionBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    sessionBanner
                    Divider()
                    if isSessionReady {
                        actionBar
                        Divider()
                    }
                    ProviderSessionView(
                        providerID: providerID,
                        loginURL: providerLoginURL,
                        sessionStatus: $sessionStatus,
                        lastURLString: $lastURLString,
                        webView: webViewBinding,
                        autofillCredentials: autofillCredentials,
                        onCapturedCredentials: { credentials in
                            pendingRememberCredentials = credentials
                        },
                        onNavigationBlocked: {
                            navigationWasBlocked = true
                        },
                        allowsEmbed: sessionHub?.allowsEmbed(on: .sync) ?? false,
                        diagnosticContext: DiagnosticContext(
                            runID: diagnosticRunID,
                            providerID: providerID,
                            operation: "macos_sync"
                        )
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: browserExpanded ? 120 : 0,
                        maxHeight: browserExpanded ? .infinity : 0,
                        alignment: .top
                    )
                    .opacity(browserExpanded ? 1 : 0)
                    .allowsHitTesting(browserExpanded)
                    .accessibilityHidden(!browserExpanded)
                    .clipped()

                    if !isSessionReady {
                        Divider()
                        actionBar
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(L10n.string(.syncProviderSyncTitle))
        .sheet(isPresented: $isSaveCredentialSheetPresented) {
            if let keychainServerHost {
                SaveProviderCredentialSheet(
                    serverHost: keychainServerHost,
                    mode: rememberLoginMode,
                    onOpenPasswordManager: { MacSystemApps.openPasswords() }
                ) { account in
                    preferredKeychainAccountID = account.id
                    reloadKeychainAccounts(selecting: account)
                    rememberLoginMessage = L10n.format(.credentialSavedForHost, keychainServerHost)
                }
            }
        }
        .onAppear {
            if UITestingLaunch.isActive { return }
            restoreSessionFromHub()
            isBrowserExpanded = false
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
        .onChange(of: sessionStatus) { _, newValue in
            sessionHub?.updateStatus(providerID, status: newValue)
            switch newValue {
            case .needsLogin:
                isBrowserExpanded = false
                scheduleKeychainReloadIfLoginStillRequired()
            case .sessionReady:
                isBrowserExpanded = false
                navigationWasBlocked = false
                tryAutoSavePendingCredentials()
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
                    Label(L10n.string(.syncSyncBookings), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!canSync)
                .help(canSync
                    ? L10n.string(.syncSyncBookingsHelp)
                    : L10n.string(.syncUnavailableHelp))
            }
        }
        .providerLoginDisclosure(isActive: isProviderEnabled)
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

    private var loginTrafficLight: ProviderLoginTrafficLight {
        .resolve(isEnabled: true, isLoggedIn: sessionStatus == .sessionReady)
    }

    private var sessionBannerSubtitle: String {
        ProviderSessionCopy.macSubtitle(
            navigationWasBlocked: navigationWasBlocked,
            isSessionReady: loginTrafficLight == .green
        )
    }

    private var showsApplePasskeyHint: Bool {
        AuthIdentityProviderHost.showsApplePasskeyHint(
            needsLogin: sessionStatus == .needsLogin,
            urlAbsoluteString: lastURLString
        )
    }

    private var sessionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: loginTrafficLight == .green
                  ? "checkmark.circle.fill"
                  : "person.crop.circle.badge.questionmark")
                .foregroundStyle(loginTrafficLight.color)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(loginTrafficLight.displayLabel)
                    .font(.headline)
                Text(sessionBannerSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if showsApplePasskeyHint {
                    SyncApplePasskeyHintLabel()
                }
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
                Picker(L10n.string(.syncAccountPicker), selection: selectedAccountBinding) {
                    Text(L10n.string(.syncChooseAccount)).tag(Optional<KeychainCredentialAccount>.none)
                    ForEach(keychainAccounts) { account in
                        Text(L10n.format(.syncAccountLabel, account.username, account.serverHost)).tag(Optional(account))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                .controlSize(.regular)
            } else if let selectedKeychainAccount {
                Text(selectedKeychainAccount.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(L10n.format(.syncAccountLabel, selectedKeychainAccount.username, selectedKeychainAccount.serverHost))
            }

            Button {
                insertKeychainCredentials()
            } label: {
                Label(L10n.string(.actionFillCredentials), systemImage: "key.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!canInsertKeychainCredentials)
            .help(
                canInsertKeychainCredentials
                    ? L10n.string(.syncFillCredentialsHelp)
                    : (keychainMessage ?? L10n.string(.syncNoAccountSelected))
            )

            Button {
                openRememberLoginSheet()
            } label: {
                Label(L10n.string(.actionRememberLogin), systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(keychainServerHost == nil)
            .help(L10n.string(.syncRememberLoginHelp))
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
            if let rememberLoginMessage {
                Text(rememberLoginMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
                VStack(alignment: .leading, spacing: 8) {
                    CopyableLabel(
                        title: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        textStyle: .callout,
                        textColor: .systemRed,
                        iconColor: .red
                    )
                    if let pane = store?.privacySettingPane {
                        OpenPrivacySettingsButton(pane: pane)
                    }
                    PublicGitHubIssueReportActions(
                        syncError: errorMessage,
                        providerID: store?.messageProviderID ?? providerID,
                        store: store
                    )
                }
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
                            openRememberLoginSheet()
                        } label: {
                            Label(L10n.string(.actionRememberLogin), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(keychainServerHost == nil)

                        Button {
                            if !MacSystemApps.openPasswords() {
                                appendKeychainMessage(L10n.string(.syncPasswordsAppNotFound))
                            }
                        } label: {
                            Label(L10n.string(.actionOpenPasswords), systemImage: "key.horizontal")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button {
                            if !MacSystemApps.openKeychainAccess() {
                                appendKeychainMessage(L10n.string(.syncKeychainAccessNotFound))
                            }
                        } label: {
                            Label(L10n.string(.actionOpenKeychain), systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }

            HStack(alignment: .center, spacing: 12) {
                if !isSessionReady {
                    Text(L10n.string(.syncAfterLoginHint))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                } else {
                    Spacer(minLength: 0)
                }

                if showsBrowserCollapseControl {
                    Button {
                        isBrowserExpanded.toggle()
                    } label: {
                        Label(
                            browserExpanded ? L10n.string(.syncBrowserHide) : L10n.string(.syncBrowserShow),
                            systemImage: browserExpanded
                                ? "rectangle.compress.vertical"
                                : "rectangle.expand.vertical"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityIdentifier(UITestingIdentifiers.syncBrowserCollapse)
                    .help(browserExpanded
                        ? L10n.string(.syncBrowserHideHelp)
                        : L10n.string(.syncBrowserShowHelp))
                }

                if isSessionReady {
                    Button {
                        Task { await runSync() }
                    } label: {
                        if store?.isSyncing == true {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 8)
                        } else {
                            Text(L10n.string(.actionSyncNow))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(!canStartSync)
                    .help(canStartSync
                        ? L10n.string(.syncSyncNowHelp)
                        : L10n.string(.syncUnavailableHelp))
                }
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
        let runID = UUID()
        diagnosticRunID = runID
        await store.sync(
            providerID: providerID,
            webView: sessionWebView,
            settings: settings,
            navigationHintURLs: navigationHintURLs(for: providerID),
            diagnosticContext: DiagnosticContext(
                runID: runID,
                providerID: providerID,
                operation: "provider_sync"
            )
        )
    }

    private func navigationHintURLs(for providerID: ProviderID) -> [URL] {
        NavigationHintURLs.ordered(
            localURLString: lastURLString,
            hubURLString: sessionHub?.lastURLString(for: providerID)
        )
    }

    private func validateProviderAvailability() {
        missingProviderMessage = nil
        guard let providerRegistry else {
            return
        }
        guard providerRegistry.provider(id: providerID) != nil else {
            missingProviderMessage = L10n.format(.syncProviderUnavailable, providerID.rawValue)
            return
        }
        guard providerLoginURL != nil else {
            missingProviderMessage = L10n.format(.syncProviderLoginMetadataMissing, providerID.rawValue)
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

    private func openRememberLoginSheet() {
        ProviderRememberLogin.beginSheet(
            sessionReady: sessionStatus == .sessionReady,
            pending: pendingRememberCredentials,
            mode: &rememberLoginMode,
            message: &rememberLoginMessage
        )
        isSaveCredentialSheetPresented = true
    }

    @MainActor
    private func tryAutoSavePendingCredentials() {
        ProviderRememberLogin.autoSaveIfPending(
            pending: &pendingRememberCredentials,
            serverHost: keychainServerHost,
            rememberAutomatically: rememberLoginAutomatically,
            message: &rememberLoginMessage
        ) { account in
            preferredKeychainAccountID = account.id
            reloadKeychainAccounts(selecting: account)
        }
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
            keychainMessage = L10n.string(.syncNoKeychainHost)
            return
        }

        do {
            let accounts = try KeychainCredentialStore().accounts(serverHost: host)
            keychainAccounts = accounts
            applyAccountSelection(accounts: accounts, preferred: preferred, autoFill: autoFill)
        } catch {
            keychainMessage = error.localizedDescription
            let context = DiagnosticContext(
                runID: diagnosticRunID,
                providerID: providerID,
                operation: "auto_login"
            )
            Task {
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: context,
                        component: "SyncView",
                        phase: "keychain",
                        event: "account_lookup",
                        result: .failed,
                        errorType: String(describing: type(of: error)),
                        reason: DiagnosticRedactor.redact(error.localizedDescription)
                    )
                )
            }
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

        if let selected = KeychainAutoFill.pickAccount(
            from: accounts,
            storedPreferredID: preferredKeychainAccountID,
            explicitPreferred: preferred
        ) {
            selectAccount(selected, autoFill: autoFill)
            return
        }

        // Mehrere Konten ohne gespeicherte Auswahl: nichts vorauswählen.
        preferredKeychainAccountID = ""
        selectedKeychainAccount = nil
        autofillCredentials = nil
        keychainMessage = L10n.format(
            .syncKeychainAccountsFound,
            accounts.count,
            keychainServerHost ?? ""
        )
    }

    private func selectAccount(_ account: KeychainCredentialAccount?, autoFill: Bool = false) {
        selectedKeychainAccount = account
        autofillCredentials = nil
        guard let account else {
            if keychainAccounts.count > 1 {
                keychainMessage = L10n.format(
                    .syncKeychainAccountsFound,
                    keychainAccounts.count,
                    keychainServerHost ?? ""
                )
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
        let diagnosticContext = DiagnosticContext(
            runID: diagnosticRunID,
            providerID: providerID,
            operation: "auto_login"
        )
        Task { @MainActor in
            await KeychainAutoFill.runWhenWebViewReady(
                shouldContinue: {
                    sessionStatus == .needsLogin && selectedKeychainAccount != nil
                },
                webView: { sessionWebView ?? sessionHub?.webView(for: providerID) },
                action: { insertKeychainCredentials(in: $0, diagnosticContext: diagnosticContext) },
                diagnosticContext: diagnosticContext
            )
        }
    }

    @MainActor
    private func insertKeychainCredentials(
        in targetWebView: WKWebView? = nil,
        diagnosticContext: DiagnosticContext? = nil
    ) {
        guard let account = selectedKeychainAccount else { return }
        guard let webView = targetWebView ?? sessionWebView ?? sessionHub?.webView(for: providerID) else { return }
        do {
            autofillCredentials = try KeychainAutoFill.applyAccount(
                account,
                in: webView,
                diagnosticContext: diagnosticContext
            )
            keychainMessage = nil
        } catch {
            autofillCredentials = nil
            keychainMessage = error.localizedDescription
            let context = diagnosticContext ?? DiagnosticContext(
                runID: diagnosticRunID,
                providerID: providerID,
                operation: "auto_login"
            )
            Task {
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: context,
                        component: "SyncView",
                        phase: "keychain",
                        event: "credential_load",
                        result: .failed,
                        errorType: String(describing: type(of: error)),
                        reason: DiagnosticRedactor.redact(error.localizedDescription)
                    )
                )
            }
        }
    }

    private func appendKeychainMessage(_ suffix: String) {
        if let existing = keychainMessage, !existing.isEmpty {
            keychainMessage = existing + "\n\n" + suffix
        } else {
            keychainMessage = suffix
        }
    }
}
