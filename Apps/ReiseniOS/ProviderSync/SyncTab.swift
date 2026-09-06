import SwiftUI
import SwiftData
import WebKit
import UIKit

import ReisenAppCore
import ReisenProviderSync
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

struct SyncTab: View {
    @Binding var sessionChromeEpoch: Int
    var isSelected: Bool
    var onOpenSettings: () -> Void
    var onReopenProviderSetup: () -> Void

    @Environment(\.syncStore) private var syncStore
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.providerEnableEpoch) private var providerEnableEpoch

    private var enabledProviderIDs: [ProviderID] {
        _ = providerEnableEpoch
        return providerRegistry?.enabledSyncProviderIDs() ?? []
    }

    private var shouldShowProviderSetupReopen: Bool {
        _ = providerEnableEpoch
        return !ProviderFirstLaunchSetup.isInitialSetupHidden()
            && enabledProviderIDs.isEmpty
    }

    @State private var selectedProviderID: ProviderID = .check24
    @State private var webView: WKWebView?
    @State private var showCreateTrip = false
    @State private var showCredentialSheet = false
    @State private var isKeyboardVisible = false
    @State private var selectedKeychainAccount: KeychainCredentialAccount?
    @State private var keychainAccounts: [KeychainCredentialAccount] = []
    @State private var keychainMessage: String?
    @State private var keychainAutoFillTask: Task<Void, Never>?
    @State private var pendingRememberCredentials: ProviderCredentials?
    @State private var rememberLoginMode: ProviderRememberLoginMode = .passwordManual
    @State private var rememberLoginMessage: String?
    @State private var navigationWasBlocked = false
    @State private var diagnosticRunID = UUID()
    @State private var authPopupURLAbsoluteString: String?

    @AppStorage(AppSettingsKeys.rememberLoginAutomatically)
    private var rememberLoginAutomatically: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if enabledProviderIDs.isEmpty {
                    emptyProviders
                } else {
                    syncContent
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .ignoresSafeArea(.keyboard)
            .navigationTitle(L10n.string(.syncTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    providerSwitcher
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(L10n.string(.actionCreateTrip))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    GlobalChromeTrailingToolbar(
                        sessionChromeEpoch: $sessionChromeEpoch
                    )
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                TripEditorSheet(mode: .create, onSaved: { _ in })
                .reisenSheetDetents()
            }
            .sheet(isPresented: $showCredentialSheet) {
                if let host = credentialServerHost() {
                    SaveProviderCredentialSheet(
                        serverHost: host,
                        mode: rememberLoginMode
                    ) { account in
                        showCredentialSheet = false
                        let decision = ProviderRememberLogin.applyAfterSavedAccount(
                            account: account,
                            sessionNeedsLogin: sessionStatus == .needsLogin,
                            mode: rememberLoginMode,
                            setPreferredAccountID: setPreferredKeychainAccountID
                        )
                        reloadKeychainAccounts(autoFill: decision.shouldAutoFill)
                        rememberLoginMessage = L10n.format(.credentialSavedForHost, host)
                        let context = DiagnosticContext(
                            runID: diagnosticRunID,
                            providerID: selectedProviderID,
                            operation: "ios_auto_login"
                        )
                        Task {
                            await DiagnosticLogger.shared.record(
                                DiagnosticEvent(
                                    context: context,
                                    component: "SyncTab",
                                    phase: "keychain",
                                    event: "credential_save_continue",
                                    result: decision.shouldAutoFill ? .started : .skipped,
                                    reason: decision.reason
                                )
                            )
                        }
                    }
                }
            }
            .onAppear {
                sessionHub?.syncEnabledProviders(Set(enabledProviderIDs))
                ensureSelectedProviderIsEnabled()
            }
            .onChange(of: enabledProviderIDs) { _, _ in
                sessionHub?.syncEnabledProviders(Set(enabledProviderIDs))
                ensureSelectedProviderIsEnabled()
            }
            .onChange(of: selectedProviderID) { _, newProviderID in
                navigationWasBlocked = false
                webView = sessionHub?.webView(for: newProviderID)
                guard enabledProviderIDs.contains(newProviderID) else { return }
                guard let sessionHub else { return }
                if sessionHub.status(for: newProviderID) != .sessionReady {
                    sessionHub.updateStatus(newProviderID, status: .needsLogin)
                }
                clearKeychainRuntimeState()
                pendingRememberCredentials = nil
                if sessionHub.status(for: newProviderID) == .needsLogin {
                    scheduleKeychainReloadIfLoginStillRequired()
                }
            }
            .onChange(of: sessionChromeEpoch) { _, _ in
                if sessionStatus == .sessionReady {
                    navigationWasBlocked = false
                }
            }
            .onChange(of: isSelected) { _, selected in
                if !selected { isKeyboardVisible = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                guard isSelected else { return }
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .providerLoginDisclosure(isActive: !enabledProviderIDs.isEmpty)
            .onChange(of: showsApplePasskeyHint) { _, visible in
                guard visible else { return }
                recordApplePasskeyHintVisible()
            }
        }
    }

    private var emptyProviders: some View {
        ContentUnavailableView {
            Label(L10n.string(.syncNoPortals), systemImage: "switch.2")
        } description: {
            Text(L10n.string(.syncEnablePortalsHint))
        } actions: {
            if shouldShowProviderSetupReopen {
                Button(L10n.string(.setupProvidersReopen)) {
                    onReopenProviderSetup()
                }
                .accessibilityIdentifier(UITestingIdentifiers.providerSetupReopen)
            }
            Button(L10n.string(.actionGoToSettings)) {
                onOpenSettings()
            }
        }
    }

    private var syncContent: some View {
        let sessionReady = sessionStatus == .sessionReady
        return VStack(spacing: 0) {
            if SyncBrowserChrome.showsLoginChromeAboveWebView(isSessionReady: sessionReady) {
                loginChrome
            } else {
                sessionBanner
            }
            Divider()

            WebViewHost(
                loginURL: loginURLForSelectedProvider(),
                providerID: selectedProviderID,
                diagnosticContext: DiagnosticContext(
                    runID: diagnosticRunID,
                    providerID: selectedProviderID,
                    operation: "ios_sync"
                ),
                passwordAutofillAllowedHosts: loginConfiguration?.passwordAutofillAllowedHosts ?? [],
                webView: webViewBinding,
                allowsEmbed: sessionHub?.allowsEmbed(on: .sync) ?? false,
                onDidFinish: { finishedWebView in
                    handleWebDidFinish(finishedWebView)
                },
                onAuthPopupURLChange: { urlString in
                    authPopupURLAbsoluteString = urlString
                },
                onCapturedCredentials: { credentials in
                    pendingRememberCredentials = credentials
                },
                onNavigationBlocked: {
                    navigationWasBlocked = true
                }
            )
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()

            if SyncBrowserChrome.showsBottomActionBar(isSessionReady: sessionReady),
               !isKeyboardVisible {
                actionBar
            }
        }
    }

    @ViewBuilder
    private var providerSwitcher: some View {
        if enabledProviderIDs.isEmpty {
            Text(L10n.string(.syncTitle))
                .font(.headline)
        } else if enabledProviderIDs.count == 1 {
            providerSwitcherLabel
        } else {
            Menu {
                Picker(L10n.string(.syncProvider), selection: $selectedProviderID) {
                    ForEach(enabledProviderIDs, id: \.self) { id in
                        Text(providerName(for: id)).tag(id)
                    }
                }
            } label: {
                providerSwitcherLabel
            }
            .menuIndicator(.hidden)
            .accessibilityLabel(L10n.string(.syncProvider))
            .accessibilityValue(providerName(for: selectedProviderID))
            .accessibilityHint(L10n.string(.syncProviderPickerHint))
        }
    }

    private var providerSwitcherLabel: some View {
        HStack(spacing: 6) {
            Text(providerName(for: selectedProviderID))
                .font(.headline)
                .lineLimit(1)
            if enabledProviderIDs.count > 1 {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            trafficLightDot(size: 8)
        }
        .accessibilityElement(children: .combine)
    }

    private var trafficLight: ProviderLoginTrafficLight {
        _ = sessionChromeEpoch
        return ProviderLoginTrafficLight.resolve(
            isEnabled: true,
            isLoggedIn: sessionHub?.isLoggedIn(for: selectedProviderID)
        )
    }

    private func trafficLightDot(size: CGFloat) -> some View {
        Circle()
            .fill(trafficLight.color)
            .frame(width: size, height: size)
            .help(trafficLight.displayLabel)
    }

    private var trafficLightAccessibilityLabel: String {
        trafficLight.displayLabel
    }

    private func providerName(for id: ProviderID) -> String {
        providerRegistry?.provider(id: id)?.displayName ?? id.displayName
    }

    private var selectedSessionWebView: WKWebView? {
        sessionHub?.webView(for: selectedProviderID)
    }

    private var webViewBinding: Binding<WKWebView?> {
        Binding(
            get: { selectedSessionWebView },
            set: { newValue in
                webView = newValue
                sessionHub?.updateWebView(selectedProviderID, webView: newValue)
            }
        )
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
        let targetWebView = selectedSessionWebView
        guard targetWebView != nil else { return false }
        guard syncStore.isSyncing != true else { return false }
        return sessionStatus == .sessionReady
    }

    private func loginURLForSelectedProvider() -> URL? {
        loginConfiguration?.loginURL
    }

    private var loginConfiguration: (any TravelProviderLoginConfiguration)? {
        providerRegistry?.provider(id: selectedProviderID) as? TravelProviderLoginConfiguration
    }

    private func credentialServerHost() -> String? {
        loginConfiguration?.keychainServerHost
    }

    private func preferredKeychainAccountID() -> String {
        UserDefaults.standard.string(
            forKey: AppSettingsKeys.preferredKeychainAccountKey(for: selectedProviderID)
        ) ?? ""
    }

    private func setPreferredKeychainAccountID(_ value: String) {
        UserDefaults.standard.set(
            value,
            forKey: AppSettingsKeys.preferredKeychainAccountKey(for: selectedProviderID)
        )
    }

    @Environment(\.providerNativeAppPresence) private var nativeAppPresence

    private var sessionBannerSubtitle: String {
        ProviderSessionCopy.iosSubtitle(
            navigationWasBlocked: navigationWasBlocked,
            isSessionReady: sessionStatus == .sessionReady,
            isNativeAppInstalled: nativeAppPresence.isInstalled(selectedProviderID)
        )
    }

    private var showsApplePasskeyHint: Bool {
        AuthIdentityProviderHost.showsApplePasskeyHint(
            needsLogin: sessionStatus == .needsLogin,
            urlAbsoluteString: lastURLString,
            authPopupURLAbsoluteString: authPopupURLAbsoluteString
        )
    }

    private var sessionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            trafficLightDot(size: 14)
                .accessibilityLabel(Text(trafficLightAccessibilityLabel))

            VStack(alignment: .leading, spacing: 2) {
                Text(trafficLight.displayLabel)
                    .font(.headline)
                if !isKeyboardVisible {
                    Text(sessionBannerSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    if showsApplePasskeyHint {
                        SyncApplePasskeyHintLabel()
                    }
                }
            }

            Spacer(minLength: 8)

            if !isKeyboardVisible, let lastURLString {
                Text(lastURLString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .trailing)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isKeyboardVisible ? 6 : 10)
        .background(.bar)
    }

    /// HIG Login-Chrome: Status + Credential-CTAs oberhalb der WebView (wie macOS).
    private var loginChrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            SyncLoginChromeAdaptiveLayout {
                loginChromeStatusColumn
            } credentials: {
                VStack(alignment: .leading, spacing: 8) {
                    credentialControls
                    if let keychainMessage {
                        Text(keychainMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let rememberLoginMessage {
                Text(rememberLoginMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isKeyboardVisible ? 6 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(.bar)
    }

    private var loginChromeStatusColumn: some View {
        HStack(alignment: .top, spacing: 10) {
            trafficLightDot(size: 14)
                .padding(.top, 4)
                .accessibilityLabel(Text(trafficLightAccessibilityLabel))

            VStack(alignment: .leading, spacing: 4) {
                Text(trafficLight.displayLabel)
                    .font(.headline)
                    .accessibilityIdentifier(UITestingIdentifiers.syncLoginChrome)
                if !isKeyboardVisible {
                    Text(sessionBannerSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if showsApplePasskeyHint {
                        SyncApplePasskeyHintLabel()
                    }
                }
            }
        }
    }

    private var canInsertKeychainCredentials: Bool {
        selectedKeychainAccount != nil && selectedSessionWebView != nil
    }

    private var selectedAccountBinding: Binding<KeychainCredentialAccount?> {
        Binding(
            get: { selectedKeychainAccount },
            set: { newValue in
                if let newValue {
                    selectAccount(newValue, autoFill: false)
                } else {
                    selectedKeychainAccount = nil
                    setPreferredKeychainAccountID("")
                }
            }
        )
    }

    @ViewBuilder
    private var credentialControls: some View {
        HStack(spacing: 8) {
            if SyncBrowserChrome.showsAccountPicker(accountCount: keychainAccounts.count) {
                Picker(L10n.string(.syncAccountPicker), selection: selectedAccountBinding) {
                    Text(L10n.string(.syncChooseAccount)).tag(Optional<KeychainCredentialAccount>.none)
                    ForEach(keychainAccounts) { account in
                        Text(account.username).tag(Optional(account))
                    }
                }
                .labelsHidden()
            } else if SyncBrowserChrome.showsSelectedAccountLabel(accountCount: keychainAccounts.count),
                      let selectedKeychainAccount {
                Text(selectedKeychainAccount.username)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if SyncBrowserChrome.showsFillCredentialsControl(accountCount: keychainAccounts.count) {
                Button {
                    insertKeychainCredentials()
                } label: {
                    Label(L10n.string(.actionFillCredentials), systemImage: "key.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canInsertKeychainCredentials)
                .accessibilityIdentifier(UITestingIdentifiers.syncFillCredentials)
            }

            Button {
                openRememberLoginSheet()
            } label: {
                Label(L10n.string(.actionRememberLogin), systemImage: "key")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(credentialServerHost() == nil)
            .accessibilityIdentifier(UITestingIdentifiers.syncRememberLogin)

            Spacer(minLength: 0)
        }
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let rememberLoginMessage {
                Text(rememberLoginMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let statusMessage = syncStore?.statusMessage {
                Text(statusMessage).foregroundStyle(.secondary)
            }
            if let errorMessage = syncStore?.errorMessage {
                syncErrorBanner(
                    errorMessage,
                    privacyPane: syncStore?.privacySettingPane
                )
            }

            HStack(spacing: 12) {
                if SyncBrowserChrome.showsRememberLoginInBottomBar(
                    isSessionReady: sessionStatus == .sessionReady
                ) {
                    Button {
                        openRememberLoginSheet()
                    } label: {
                        Label(L10n.string(.actionRememberLogin), systemImage: "key")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(credentialServerHost() == nil)
                    .accessibilityIdentifier(UITestingIdentifiers.syncRememberLogin)
                }

                Spacer()

                Button {
                    guard let syncStore else { return }
                    let targetWebView = selectedSessionWebView
                    guard let targetWebView else { return }
                    let runID = UUID()
                    diagnosticRunID = runID
                    Task {
                        await syncStore.sync(
                            providerID: selectedProviderID,
                            webView: targetWebView,
                            settings: .fromUserDefaults(),
                            navigationHintURLs: navigationHintURLsForSync(),
                            diagnosticContext: DiagnosticContext(
                                runID: runID,
                                providerID: selectedProviderID,
                                operation: "provider_sync"
                            )
                        )
                    }
                } label: {
                    if syncStore?.isSyncing == true, syncStore?.syncingProviderID == selectedProviderID {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text(L10n.string(.actionSyncNow))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canStartSync)
            }
        }
        .padding(16)
        .background(.bar)
    }

    @ViewBuilder
    private func syncErrorBanner(
        _ errorMessage: String,
        privacyPane: PrivacySettingPane?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                privacyPane != nil ? L10n.string(.syncAccessDenied) : L10n.string(.syncError),
                systemImage: privacyPane != nil ? "lock.slash" : "exclamationmark.triangle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)

            Text(errorMessage)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .font(.footnote)

            if let privacyPane {
                OpenPrivacySettingsButton(pane: privacyPane)
            }
            PublicGitHubIssueReportActions(
                syncError: errorMessage,
                providerID: syncStore?.messageProviderID ?? selectedProviderID,
                store: syncStore
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func ensureSelectedProviderIsEnabled() {
        guard let resolved = EnabledProviderSelection.resolved(
            selected: selectedProviderID,
            enabled: enabledProviderIDs
        ) else { return }
        if resolved != selectedProviderID {
            selectedProviderID = resolved
        }
    }

    private func navigationHintURLsForSync() -> [URL] {
        NavigationHintURLs.ordered(
            localURLString: webView?.url?.absoluteString,
            hubURLString: sessionHub?.lastURLString(for: selectedProviderID)
        )
    }

    @MainActor
    private func handleWebDidFinish(_ finishedWebView: WKWebView) {
        guard let hub = sessionHub else { return }
        ProviderSessionNavigation.handleDidFinish(
            webView: finishedWebView,
            providerID: selectedProviderID,
            hub: hub,
            enabledProviderIDs: Set(enabledProviderIDs),
            notifyAlways: true,
            diagnosticContext: DiagnosticContext(
                runID: diagnosticRunID,
                providerID: selectedProviderID,
                operation: "ios_sync"
            )
        ) {
            sessionChromeEpoch &+= 1
        }
        if hub.status(for: selectedProviderID) == .needsLogin {
            scheduleKeychainReloadIfLoginStillRequired()
        } else if hub.status(for: selectedProviderID) == .sessionReady {
            tryAutoSavePendingCredentials()
            clearKeychainRuntimeState()
        } else {
            clearKeychainRuntimeState()
        }
    }

    private func openRememberLoginSheet() {
        ProviderRememberLogin.beginSheet(
            sessionReady: sessionStatus == .sessionReady,
            pending: pendingRememberCredentials,
            mode: &rememberLoginMode,
            message: &rememberLoginMessage
        )
        showCredentialSheet = true
    }

    @MainActor
    private func tryAutoSavePendingCredentials() {
        ProviderRememberLogin.autoSaveIfPending(
            pending: &pendingRememberCredentials,
            serverHost: credentialServerHost(),
            rememberAutomatically: rememberLoginAutomatically,
            message: &rememberLoginMessage
        ) { account in
            setPreferredKeychainAccountID(account.id)
            selectedKeychainAccount = account
        }
    }

    private func clearKeychainRuntimeState() {
        keychainAutoFillTask?.cancel()
        keychainAutoFillTask = nil
        selectedKeychainAccount = nil
        keychainAccounts = []
        keychainMessage = nil
    }

    private func scheduleKeychainReloadIfLoginStillRequired() {
        keychainAutoFillTask?.cancel()
        keychainAutoFillTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: KeychainAutoFill.loginSettleDelayNanoseconds)
            guard !Task.isCancelled else { return }
            guard sessionStatus == .needsLogin else { return }
            reloadKeychainAccounts(autoFill: true)
        }
    }

    @MainActor
    private func reloadKeychainAccounts(autoFill: Bool = false) {
        guard sessionStatus == .needsLogin else { return }
        selectedKeychainAccount = nil
        keychainAccounts = []
        keychainMessage = nil

        guard let host = credentialServerHost() else {
            keychainMessage = L10n.string(.syncNoKeychainHost)
            return
        }

        do {
            let accounts = try KeychainCredentialStore().accounts(serverHost: host)
            keychainAccounts = accounts
            applyAccountSelection(accounts: accounts, autoFill: autoFill)
        } catch {
            selectedKeychainAccount = nil
            keychainMessage = error.localizedDescription
            let context = DiagnosticContext(
                runID: diagnosticRunID,
                providerID: selectedProviderID,
                operation: "auto_login"
            )
            Task {
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: context,
                        component: "SyncTab",
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

    @MainActor
    private func applyAccountSelection(
        accounts: [KeychainCredentialAccount],
        autoFill: Bool = false
    ) {
        if accounts.isEmpty {
            setPreferredKeychainAccountID("")
            selectedKeychainAccount = nil
            keychainMessage = KeychainCredentialStore.CredentialStoreError
                .noEntry(serverHost: credentialServerHost() ?? "")
                .errorDescription
            return
        }

        let storedID = preferredKeychainAccountID()
        if let selected = KeychainAutoFill.pickAccount(
            from: accounts,
            storedPreferredID: storedID
        ) {
            selectAccount(selected, autoFill: autoFill)
            return
        }

        setPreferredKeychainAccountID("")
        selectedKeychainAccount = nil
        keychainMessage = L10n.format(
            .syncKeychainAccountsFound,
            accounts.count,
            credentialServerHost() ?? "",
            L10n.string(.actionRememberLogin)
        )
    }

    @MainActor
    private func selectAccount(_ account: KeychainCredentialAccount, autoFill: Bool = false) {
        selectedKeychainAccount = account
        setPreferredKeychainAccountID(account.id)
        keychainMessage = nil
        if autoFill {
            scheduleAutoFillFromKeychain()
        }
    }

    private func scheduleAutoFillFromKeychain() {
        KeychainAutoFill.startWebViewReadyTask(
            existing: &keychainAutoFillTask,
            shouldContinue: {
                !Task.isCancelled
                    && sessionStatus == .needsLogin
                    && selectedKeychainAccount != nil
            },
            webView: { selectedSessionWebView },
            action: { insertKeychainCredentials(in: $0) },
            diagnosticContext: DiagnosticContext(
                runID: diagnosticRunID,
                providerID: selectedProviderID,
                operation: "ios_auto_login"
            )
        )
    }

    @MainActor
    private func insertKeychainCredentials(in targetWebView: WKWebView? = nil) {
        guard let account = selectedKeychainAccount else { return }
        guard let webView = targetWebView ?? selectedSessionWebView else { return }
        do {
            try KeychainAutoFill.applyAccount(
                account,
                in: webView,
                diagnosticContext: DiagnosticContext(
                    runID: diagnosticRunID,
                    providerID: selectedProviderID,
                    operation: "ios_auto_login"
                )
            )
        } catch {
            selectedKeychainAccount = nil
            keychainMessage = error.localizedDescription
            let context = DiagnosticContext(
                runID: diagnosticRunID,
                providerID: selectedProviderID,
                operation: "ios_auto_login"
            )
            Task {
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: context,
                        component: "SyncTab",
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

    private func recordApplePasskeyHintVisible() {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: diagnosticRunID,
                        providerID: selectedProviderID,
                        operation: "sync_login"
                    ),
                    component: "SyncApplePasskeyHint",
                    phase: "login",
                    event: "apple_passkey_hint",
                    result: .succeeded,
                    url: authPopupURLAbsoluteString ?? lastURLString,
                    reason: "apple_idp_visible"
                )
            )
        }
    }
}
