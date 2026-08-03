import Foundation
import Security

extension KeychainCredentialStore {
    public enum CredentialStoreError: LocalizedError, Equatable {
        case noEntry(serverHost: String)
        case unsupportedItem
        case unexpectedItemAttributes
        case saveFailed(status: OSStatus)
        case emptyUsername
        case emptyPassword

        public var errorDescription: String? {
            switch self {
            case .noEntry(let serverHost):
                return """
                Kein lesbares Konto für '\(serverHost)'.
                Passwords-App-Einträge sind für andere Apps gesperrt.
                Primärweg: „Konto speichern…“ — E-Mail und Kennwort aus Passwords hier hinterlegen.
                (Optional: Internetpasswort in der Schlüsselbundverwaltung für '\(serverHost)' anlegen.)
                """
            case .unsupportedItem:
                return "Keychain-Eintrag hat ein unerwartetes Format."
            case .unexpectedItemAttributes:
                return "Keychain-Eintrag fehlen notwendige Attribute."
            case .saveFailed(let status):
                return "Keychain-Speichern fehlgeschlagen (Status \(status))."
            case .emptyUsername:
                return "Benutzername/E-Mail darf nicht leer sein."
            case .emptyPassword:
                return "Kennwort darf nicht leer sein."
            }
        }
    }
}
