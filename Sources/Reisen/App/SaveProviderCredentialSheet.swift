import SwiftUI
import AppKit
import ReisenProviders

/// Speichert ein Provider-Konto als lesbares Internetpasswort (z. B. aus Passwords kopiert).
struct SaveProviderCredentialSheet: View {
    let serverHost: String
    var onSaved: (KeychainCredentialAccount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Die Passwords-App kann diese App nicht automatisch befüllen. "
                            + "Öffne Passwords, kopiere E-Mail und Kennwort für \(serverHost), "
                            + "und speichere sie hier — danach Auswahl und Ausfüllen."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        if !MacSystemApps.openPasswords() {
                            errorMessage = "Passwords-App wurde nicht gefunden."
                        }
                    } label: {
                        Label("Passwords öffnen", systemImage: "key.horizontal")
                    }
                }

                Section("Konto für \(serverHost)") {
                    TextField("E-Mail / Benutzername", text: $username)
                        .textContentType(.username)
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
            .formStyle(.grouped)
            .navigationTitle("Konto speichern")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(isSaving || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
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
