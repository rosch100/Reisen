# Security Code AutoFill (OTP) im Provider-WKWebView

## Ziel

Beim Provider-Login in der eingebetteten `WKWebView` soll Apples **Security Code AutoFill** greifen: Codes aus Messages/Mail werden als System-Vorschlag angeboten und vom Nutzer bestätigt. Es gibt keinen API-Zugriff auf SMS-/Mail-Inhalte.

## Entscheidung

- **Variante A:** OTP-Eingabefelder im Web-Dokument mit `autocomplete="one-time-code"` markieren.
- **Ansatz 2:** Markierung per JS bei Navigation plus `MutationObserver` für dynamisch eingefügte Felder.

## Architektur

- Neue Plattform-Hilfe `OneTimeCodeAutofill` (analog `LoginAutofill` / `RememberBrowser`).
- URL-Heuristik `AuthPageURLHeuristic` (SSOT): wann AutoFill-JS angewendet wird (Login- oder OTP-ähnliche Seiten).
- Aufruf aus der generischen `ProviderSessionView` (alle Provider) bei jeder Navigation (`didCommit`/`didFinish`); JS ist idempotent.
- Kein Auslesen von SMS/Mail, kein programmatisches Einfügen des Codes, keine Associated Domains (Provider sendet SMS).

## Komponenten

### `AuthPageURLHeuristic` (ReisenProviders)

- `looksLikeLoginPage`
- `looksLikeOneTimeCodeChallenge`
- `shouldApplyOneTimeCodeAutofill` = Login ∨ OTP-Challenge

### `OneTimeCodeAutofill` (Reisen/Platform)

- JS: OTP-ähnliche Inputs erkennen, `autocomplete="one-time-code"` setzen, Username/Passwort ausschließen.
- Einmaliger `MutationObserver` pro Dokument (`window.__reisenOTCInstalled`).
- `apply(in: WKWebView)` via `evaluateJavaScript`.

## Ablauf

1. Navigation `didCommit` / `didFinish`.
2. Wenn `shouldApplyOneTimeCodeAutofill` → `OneTimeCodeAutofill.apply`.
3. System zeigt Security-Code-Vorschlag; Nutzer bestätigt.

## Fehlerbehandlung

- JS-Fehler still ignorieren (wie bestehendes Autofill); manueller Eintrag bleibt möglich.
- Keine Dummy-Codes, kein Keychain-OTP.

## Tests

- Unit-Tests für `AuthPageURLHeuristic`.
- Manuell: Check24-2FA mit SMS/Mail-Vorschlag.

## Nicht im Scope

- Associated Domains / domain-bound SMS
- Natives OTP-Feld außerhalb der WebView
- Programmatisches Lesen von Messages/Mail
