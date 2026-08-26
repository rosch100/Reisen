import SwiftUI
import ReisenProviders

/// Speichert ein Provider-Konto in der App-Keychain — ohne macOS-Passwords-App-Deep-Link.
public struct SaveProviderCredentialSheet: View {
    let serverHost: String
    var onSaved: (KeychainCredentialAccount) -> Void
    var onOpenPasswordManager: (() -> Bool)?

    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    public init(
        serverHost: String,
        onOpenPasswordManager: (() -> Bool)? = nil,
        onSaved: @escaping (KeychainCredentialAccount) -> Void
    ) {
        self.serverHost = serverHost
        self.onOpenPasswordManager = onOpenPasswordManager
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Kopiere Benutzername und Kennwort aus der Passwords-App (oder einem anderen Manager) "
                            + "für \(serverHost) und speichere sie hier."
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
                }

                Section("Konto für \(serverHost)") {
                    TextField("E-Mail / Benutzername", text: $username)
                        .textContentType(.username)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                    SecureField("Kennwort", text: $password)
                        .textContentType(.password)
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
            .navigationTitle("Konto speichern")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .reisenSheetDetents()
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(
                            isSaving
                                || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || password.isEmpty
                        )
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
#endif
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
            onSaved(account)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
