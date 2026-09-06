import SwiftUI
import ReisenDomain
import ReisenProviders
import ReisenAppCore
import ReisenSharedUI

/// Speichert eine Provider-Anmeldung — Passwort-Konto oder Session-Hinweis (Apple/Passkey/OAuth).
public struct SaveProviderCredentialSheet: View {
    let serverHost: String
    let mode: ProviderRememberLoginMode
    var onSaved: (KeychainCredentialAccount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    public init(
        serverHost: String,
        mode: ProviderRememberLoginMode = .passwordManual,
        onSaved: @escaping (KeychainCredentialAccount) -> Void
    ) {
        self.serverHost = serverHost
        self.mode = mode
        self.onSaved = onSaved
        if case .passwordPrefill(let user, let pass) = mode {
            _username = State(initialValue: user)
            _password = State(initialValue: pass)
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                switch mode {
                case .sessionOnly:
                    sessionOnlyContent
                case .passwordManual, .passwordPrefill:
                    passwordContent
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }
#if os(iOS)
            .formStyle(.grouped)
#else
            .formStyle(.grouped)
#endif
            .navigationTitle(L10n.string(.actionRememberLogin))
            .accessibilityIdentifier(UITestingIdentifiers.syncRememberLoginSheet)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .reisenSheetDetents()
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .sessionOnly = mode {
                        Button(L10n.string(.actionUnderstood)) { dismiss() }
                    } else {
                        Button(L10n.string(.actionSaveCredential)) { save() }
                            .disabled(
                                isSaving
                                    || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || password.isEmpty
                            )
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 420, minHeight: mode == .sessionOnly ? 260 : 320)
#endif
        .onDisappear {
            clearSensitiveFields()
        }
    }

    private func clearSensitiveFields() {
        username = ""
        password = ""
    }

    @ViewBuilder
    private var sessionOnlyContent: some View {
        Section {
            Text(L10n.format(.credentialOauthSessionFooter, serverHost))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(L10n.string(.credentialSessionPersistenceFooter))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var passwordContent: some View {
        Section {
            if case .passwordManual = mode {
                Text(L10n.format(.credentialCopyFromPasswordsFooter, serverHost))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(L10n.format(.credentialSavedAccountFooter, serverHost))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        Section(L10n.format(.credentialSection, serverHost)) {
            TextField(L10n.string(.credentialEmailUsername), text: $username)
                .textContentType(ProviderRememberLoginAutoFill.usernameContentType)
                .accessibilityIdentifier(UITestingIdentifiers.syncRememberLoginUsername)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
#endif
            SecureField(L10n.string(.credentialPassword), text: $password)
                .textContentType(ProviderRememberLoginAutoFill.passwordContentType)
                .accessibilityIdentifier(UITestingIdentifiers.syncRememberLoginPassword)
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let credentials = ProviderCredentials(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        do {
            try KeychainCredentialStore().save(credentials: credentials, serverHost: serverHost)
            let account = KeychainCredentialAccount(serverHost: serverHost, username: credentials.username)
            clearSensitiveFields()
            onSaved(account)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
