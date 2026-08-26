import SwiftUI
import ReisenProviders

/// Speichert eine Provider-Anmeldung — Passwort-Konto oder Session-Hinweis (Apple/Passkey/OAuth).
public struct SaveProviderCredentialSheet: View {
    let serverHost: String
    let mode: ProviderRememberLoginMode
    var onOpenPasswordManager: (() -> Bool)?
    var onSaved: (KeychainCredentialAccount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    public init(
        serverHost: String,
        mode: ProviderRememberLoginMode = .passwordManual,
        onOpenPasswordManager: (() -> Bool)? = nil,
        onSaved: @escaping (KeychainCredentialAccount) -> Void
    ) {
        self.serverHost = serverHost
        self.mode = mode
        self.onOpenPasswordManager = onOpenPasswordManager
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
            .navigationTitle("Anmeldung merken")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .reisenSheetDetents()
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .sessionOnly = mode {
                        Button("Verstanden") { dismiss() }
                    } else {
                        Button("Speichern") { save() }
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
            Text(
                "Deine Anmeldung bei \(serverHost) (z. B. Sign in with Apple, Passkey, Google oder Facebook) "
                    + "wird über die Session in der App gespeichert — nicht als Kennwort."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                "Beim nächsten Besuch bleibst du angemeldet, solange der Provider die Session akzeptiert. "
                    + "Ein erneuter Login kann trotzdem nötig sein (2FA, abgelaufene Session)."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var passwordContent: some View {
        Section {
            if case .passwordManual = mode {
                Text(
                    "Kopiere Benutzername und Kennwort aus der Passwords-App (oder einem anderen Manager) "
                        + "für \(serverHost) und speichere sie hier für automatisches Ausfüllen."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if let onOpenPasswordManager {
                    Button {
                        if !onOpenPasswordManager() {
                            errorMessage = "Passwords-App wurde nicht gefunden."
                        }
                    } label: {
                        Label("Passwords öffnen", systemImage: "key.horizontal")
                    }
                }
            } else {
                Text(
                    "Passwort-Konto für \(serverHost) — nach dem Speichern füllt Reisen die Felder beim nächsten Login automatisch aus."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        Section("Passwort-Konto für \(serverHost)") {
            TextField("E-Mail / Benutzername", text: $username)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#endif
            SecureField("Kennwort", text: $password)
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
