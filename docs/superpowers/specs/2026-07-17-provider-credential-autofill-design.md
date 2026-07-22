# Provider-Login Credentials — Ansatz 3 (Keychain + Konto speichern)

Datum: 2026-07-17  
Status: freigegeben (Ansatz 3 vorerst; Ansatz 1 später optional)

## Kontext

Die Passwords-App füllt in eingebetteten `WKWebView`s für fremde Provider-Domains (Opodo, Booking, Check24) **nicht** wie in Safari. Gründe:

- Associated Domains (`webcredentials:`) erfordern Freigabe auf der Provider-Website — nicht verfügbar.
- System-Autofill für beliebige Domains braucht das eingeschränkte Entitlement `com.apple.developer.web-browser` (Ansatz 1, später).

## Gewählter Ansatz (3)

Primärweg in der App:

1. Lesbare Internetpasswörter (`kSecClassInternetPassword`) auflisten.
2. Bei mehreren Konten: Auswahl-UI; Auswahl pro Provider persistieren.
3. Fehlende / nur-in-Passwords-Konten: **„Konto speichern…“** (E-Mail + Kennwort aus Passwords kopieren → als Internetpasswort speichern).
4. **Ausfüllen** injiziert das gewählte Konto per JS in die Login-Felder.

Keychain-Access-App und Passwords-App öffnen nur als Hilfsaktionen.

### Bewusst nicht jetzt

- Browser-Entitlement / Safari-gleiches Passwords-Popover (Ansatz 1).
- Login nur in Safari mit Cookie-Transfer (Ansatz 2) — bricht den Sync-Pfad.

### macOS-Hinweis

Beim ersten Lesen eines Secrets kann das System einen Keychain-Freigabe-Dialog zeigen (OS-Verhalten). Danach typischerweise dauerhaft erlaubt. Vermeidbar nur mit Ansatz 1.

## Architektur

| Komponente | Rolle |
|------------|--------|
| `KeychainCredentialAccount` | Account ohne Secret (Auswahl) |
| `KeychainCredentialStore` | `accounts`, `credentials(for:)`, `save` |
| `SyncView` | Picker, Ausfüllen, Speichern-Sheet, Statusleiste auto-size |
| `SaveProviderCredentialSheet` | Manuelles Speichern aus Passwords |
| `LoginAutofill` / `LoginFieldHints` | JS-Fill + autocomplete-Hints |
| `AppSettingsKeys.preferredKeychainAccountKey` | Persistierte Auswahl |

## UX-Priorität

1. **Konto speichern…** — Hauptweg für Passwords-Konten  
2. **Konto wählen** + **Ausfüllen**  
3. Passwords öffnen / Schlüsselbundverwaltung — Nebenwege  

Statusleisten-Texte erklären Passwords-Sperre und verweisen primär auf „Konto speichern…“.

## Prüfung

1. Provider ohne lesbaren Eintrag → Hinweis + Speichern möglich.  
2. Konto speichern → erscheint in Auswahl, Ausfüllen befüllt Felder.  
3. Mehrere Konten → kein stilles Füllen ohne Auswahl; Preference bleibt.  
4. Lange Statusmeldung nicht vertikal abgeschnitten.
