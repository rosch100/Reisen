import Foundation
import WebKit
import ReisenProviders

/// Markiert Login-Felder mit `autocomplete` und meldet dynamisch hinzugefügte Felder an Swift,
/// damit Credential-Fill auch bei mehrstufigen Logins (E-Mail → Kennwort) greift.
///
/// Hinweis: Das macOS-System-Passwort-Popover (Passwords-App) erscheint in eingebetteten
/// WKWebViews für Fremd-Domains ohne Browser-Entitlement nicht. Primärweg ist deshalb
/// „Konto speichern…“ + Ausfüllen (`ProviderLoginAssistance`). Ansatz 1 (Browser-Entitlement) später optional.
enum LoginFieldHints {
    static let messageHandlerName = LoginFieldHintsScript.messageHandlerName

    @MainActor
    static func apply(in webView: WKWebView) {
        webView.evaluateJavaScript(LoginFieldHintsScript.build()) { _, _ in }
    }
}
