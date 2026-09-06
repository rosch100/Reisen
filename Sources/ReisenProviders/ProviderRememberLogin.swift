import Foundation

/// Modus für „Anmeldung merken“ — Passwort-Konto oder reine Session (Apple/Passkey/OAuth).
public enum ProviderRememberLoginMode: Sendable, Equatable {
    case passwordManual
    case passwordPrefill(username: String, password: String)
    /// Bereits in der App-Keychain gespeichertes Passwort-Konto (anzeigen/aktualisieren).
    case passwordStored(username: String, password: String)
    case sessionOnly

    /// HIG: Info-only (`sessionOnly`) hat keinen Cancel — nur Ack. Editable Modes behalten Cancel.
    public var showsCancelAction: Bool {
        switch self {
        case .sessionOnly:
            return false
        case .passwordManual, .passwordPrefill, .passwordStored:
            return true
        }
    }
}

/// SSOT für „Anmeldung merken“ (Sheet-Modus und Auto-Save nach Login).
public enum ProviderRememberLogin {
    public struct AutoSaveOutcome: Sendable, Equatable {
        public let account: KeychainCredentialAccount?
        public let message: String?
        public let shouldClearPending: Bool

        public static let skipped = AutoSaveOutcome(
            account: nil,
            message: nil,
            shouldClearPending: false
        )
    }

    public struct LoginContinueAfterSave: Equatable, Sendable {
        public let preferredAccountID: String
        public let shouldAutoFill: Bool
        public let reason: String

        public init(preferredAccountID: String, shouldAutoFill: Bool, reason: String) {
            self.preferredAccountID = preferredAccountID
            self.shouldAutoFill = shouldAutoFill
            self.reason = reason
        }
    }

    public static func loginContinueAfterSave(
        account: KeychainCredentialAccount,
        sessionNeedsLogin: Bool,
        mode: ProviderRememberLoginMode
    ) -> LoginContinueAfterSave {
        guard sessionNeedsLogin else {
            return LoginContinueAfterSave(
                preferredAccountID: account.id,
                shouldAutoFill: false,
                reason: "session_ready"
            )
        }
        switch mode {
        case .passwordManual, .passwordPrefill, .passwordStored:
            return LoginContinueAfterSave(
                preferredAccountID: account.id,
                shouldAutoFill: true,
                reason: "needs_login"
            )
        case .sessionOnly:
            return LoginContinueAfterSave(
                preferredAccountID: account.id,
                shouldAutoFill: false,
                reason: "session_only"
            )
        }
    }

    /// Host-Apply nach Speichern: Preferred-ID setzen, Fill nur über Reload-`autoFill`.
    public static func applyAfterSavedAccount(
        account: KeychainCredentialAccount,
        sessionNeedsLogin: Bool,
        mode: ProviderRememberLoginMode,
        setPreferredAccountID: (String) -> Void
    ) -> LoginContinueAfterSave {
        let decision = loginContinueAfterSave(
            account: account,
            sessionNeedsLogin: sessionNeedsLogin,
            mode: mode
        )
        setPreferredAccountID(decision.preferredAccountID)
        return decision
    }

    /// Wendet Auto-Save-Ergebnis auf View-State an (SyncTab/SyncView SSOT).
    public static func applyAutoSaveOutcome(
        _ outcome: AutoSaveOutcome,
        pending: inout ProviderCredentials?,
        message: inout String?,
        onSavedAccount: (KeychainCredentialAccount) -> Void = { _ in }
    ) {
        if let account = outcome.account {
            onSavedAccount(account)
        }
        message = outcome.message
        if outcome.shouldClearPending {
            pending = nil
        }
    }

    /// Speichert nur wenn noch nicht identisch vorhanden. Gibt das Konto zurück, wenn neu/aktualisiert.
    public static func saveIfNeeded(
        credentials: ProviderCredentials,
        serverHost: String,
        store: KeychainCredentialStore = KeychainCredentialStore()
    ) throws -> KeychainCredentialAccount? {
        let normalized = try KeychainCredentialNormalize.normalize(
            credentials: credentials,
            serverHost: serverHost
        )
        let account = KeychainCredentialAccount(
            serverHost: normalized.server,
            username: normalized.username
        )
        do {
            let existing = try store.credentials(for: account)
            if existing == credentials {
                return nil
            }
        } catch KeychainCredentialStore.CredentialStoreError.noEntry {
            // Neues Konto — unten speichern.
        }
        try store.save(credentials: credentials, serverHost: serverHost)
        return account
    }

    public static func autoSavePending(
        credentials: ProviderCredentials,
        serverHost: String,
        when rememberAutomatically: Bool,
        store: KeychainCredentialStore = KeychainCredentialStore()
    ) -> AutoSaveOutcome {
        guard rememberAutomatically else { return .skipped }

        do {
            if let account = try saveIfNeeded(
                credentials: credentials,
                serverHost: serverHost,
                store: store
            ) {
                return AutoSaveOutcome(
                    account: account,
                    message: autoSavedMessage(serverHost: serverHost),
                    shouldClearPending: true
                )
            }
            return AutoSaveOutcome(account: nil, message: nil, shouldClearPending: true)
        } catch {
            return AutoSaveOutcome(
                account: nil,
                message: autoSaveFailedMessage(error),
                shouldClearPending: false
            )
        }
    }

    public static func autoSavedMessage(serverHost: String) -> String {
        "Passwort-Konto für \(serverHost) automatisch gespeichert."
    }

    public static func autoSaveFailedMessage(_ error: Error) -> String {
        "Passwort konnte nicht gespeichert werden: \(error.localizedDescription)"
    }

    /// Sheet öffnen: Meldung leeren, Modus setzen.
    public static func beginSheet(
        sessionReady: Bool,
        pending: ProviderCredentials?,
        stored: ProviderCredentials? = nil,
        mode: inout ProviderRememberLoginMode,
        message: inout String?
    ) {
        message = nil
        mode = ProviderRememberLoginMode.forSheet(
            sessionReady: sessionReady,
            pending: pending,
            stored: stored
        )
    }

    /// Lädt bevorzugtes oder erstes Passwort-Konto für den Sheet-Prefill.
    public static func resolveStoredCredentials(
        serverHost: String,
        preferredAccountID: String,
        store: KeychainCredentialStore = KeychainCredentialStore()
    ) throws -> ProviderCredentials? {
        let accounts = try store.accounts(serverHost: serverHost)
        guard let account = KeychainAutoFill.pickAccount(
            from: accounts,
            storedPreferredID: preferredAccountID
        ) ?? accounts.first else {
            return nil
        }
        return try store.credentials(for: account)
    }

    /// Auto-Save für erfasste Formular-Credentials (SyncTab/SyncView SSOT).
    public static func autoSaveIfPending(
        pending: inout ProviderCredentials?,
        serverHost: String?,
        rememberAutomatically: Bool,
        message: inout String?,
        store: KeychainCredentialStore = KeychainCredentialStore(),
        onSavedAccount: (KeychainCredentialAccount) -> Void = { _ in }
    ) {
        guard let credentials = pending, let serverHost else { return }
        applyAutoSaveOutcome(
            autoSavePending(
                credentials: credentials,
                serverHost: serverHost,
                when: rememberAutomatically,
                store: store
            ),
            pending: &pending,
            message: &message,
            onSavedAccount: onSavedAccount
        )
    }
}

extension ProviderRememberLoginMode {
    /// Sheet-Modus: pending Capture → Prefill; sonst gespeichertes Konto; sonst Session/Manual.
    public static func forSheet(
        sessionReady: Bool,
        pending: ProviderCredentials?,
        stored: ProviderCredentials? = nil
    ) -> ProviderRememberLoginMode {
        if let pending {
            return .passwordPrefill(username: pending.username, password: pending.password)
        }
        if let stored {
            return .passwordStored(username: stored.username, password: stored.password)
        }
        return sessionReady ? .sessionOnly : .passwordManual
    }
}
