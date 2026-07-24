# Universal iOS/iPadOS App Design (Reisen)

## Ziel
Eine iPadOS/iOS-App bereitstellen, die die Kernfunktionen der macOS-App abbildet (Reisen, Buchungen, Gaps, Provider-Sync über Login im eingebetteten WebView, Settings, lokale Erinnerungen/Kalender), ohne iCloud/CloudKit in v1. Auslieferung ist TestFlight-bereit über ein separates iOS/iPadOS Target.

## Scope (v1)
- iPhone + iPad (Universal)
- Lokale SwiftData-Persistenz pro Gerät (kein Cloud Sync)
- Provider-Sync: Login im eingebetteten `WKWebView`, dann Sync-Pipeline und Darstellung von Trips/Buchungen
- Settings: Aktivierung Erinnerungen/Apple Kalender, Vorlaufzeiten, Kalender-Strategie
- Side Effects: Kalender-Einträge + Reminder/Notifications (wenn Nutzer aktiviert)
- Fehlerzustände: Store-Init-Fehler mit Reset-Dialog (destruktiv nur mit Confirm)

## Nicht-Ziele
- iCloud/CloudKit Sync zwischen Geräten
- App Store Release-Workflow und Screenshots in v1
- Catalyst
- macOS-Menü-Shortcuts 1:1 auf iOS

## Navigation & HIG
Die App nutzt iOS/iPadOS-native Muster statt der macOS-3-Spalten-Mail-Metapher 1:1 zu portieren.

### Root-Layer
`TabView` als oberste Navigationsebene, ausgestattet mit iOS/iPadOS-adaptiver Sidebar-Optik:
- `tabViewStyle(.sidebarAdaptable)`

Top-Level Tabs:
- Reisen
- Offen
- Sync
- Mehr (Einstellungen)

### Reisen & Offen
- iPad (regular width): `NavigationSplitView` (Liste + Detail)
- iPhone (compact): `NavigationStack` (Listenansicht → Detail per Push, Editor per Sheet)

### Sync Tab
Ein immersiver Bereich mit Provider-Auswahl und Status; das Login/Session-Fenster ist Hauptinhalt.
- iOS: `WKWebView` über `UIViewRepresentable`
- Steuerleiste: Provider-Auswahl, „Jetzt synchronisieren“, Statusanzeige

### Mehr (Settings)
Settings als SwiftUI `Form` mit „inset grouped“ Styling (Einstellungen so, wie iOS/PadOS es erwartet).

## Interaktions-Standards
- Destruktive Aktionen: immer `confirmationDialog` (z. B. Reise löschen, Buchung von Reise entfernen, Store-Reset)
- Empty States: `ContentUnavailableView` mit einer klaren CTA („Jetzt Sync starten“, „Provider auswählen“, etc.)
- Suche: `.searchable` auf relevanten Listen
- Copy/Text-Auswahl: iOS-nativ (Text selection); keine AppKit-spezifischen `NSTextView`-Konzepte

## Paritätskriterien (funktional)
1. Sync lädt Provider-Katalog und persistiert kanonische Domain-Entities
2. Trips/Buchungen/Gaps werden angezeigt und können bearbeitet/zugeordnet werden
3. Settings steuern Erinnerungen/Erinnerungslisten/ Kalendererstellung
4. Permission-Strings und iOS-Access-Verhalten sind korrekt

## Risiken & technische Leitplanken
- macOS-spezifische UI (AppKit-Splits, `NSViewRepresentable`, `NSWorkspace`, `NSTextView`) wird nicht via `#if` durchmischt, sondern durch iOS-native Implementationen ersetzt.
- WebView-Session und Credential-Speicherung folgen den bestehenden Provider-Ports; die iOS UI übernimmt nur die passende Host-/Wrapper-Schicht.

