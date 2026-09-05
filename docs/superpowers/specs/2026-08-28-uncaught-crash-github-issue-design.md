# App-Absturz als GitHub-Issue — Design Spec

Stand: 2026-08-28

## Problem

Reisen kann Sync-Fehler und manuelles Feedback bereits als öffentliches GitHub-Issue senden (`GitHubIssueReporter`, Opt-in `reportErrorsToGitHub`, eingebettetes Issues-Token).

`GitHubIssueCrashCatcher` fängt heute nur **Objective-C-`NSException`** (`NSSetUncaughtExceptionHandler`), schreibt `pending-crash-report.txt` und sendet beim nächsten Start.

Der Absturz vom 2026-08-28 21:37 (lokal `Reisen.app` 0.2.1) war **kein** `NSException`:

| Feld | Wert |
| --- | --- |
| Exception | `EXC_BREAKPOINT` / **SIGTRAP** |
| Frame 0 | `libswiftCore.dylib` `_assertionFailure(_:_:file:line:flags:)` |
| Queue | `com.apple.root.user-initiated-qos.cooperative` |
| Abschluss | `completeTaskWithClosure` (`libswift_Concurrency`) |
| Bilder | u. a. FoundationModels, WebKit |

Swift-`fatalError` / `preconditionFailure` / Assertion in einem `Task` enden so. Der bestehende Handler läuft nicht. Datenschutztext und App-Store-Angabe sprechen bereits von Crash-Stacks bei Opt-in — die Implementierung deckt das für Swift-Traps nicht ab.

## Ziel

Nach Opt-in denselben GitHub-Issue-Prozess nutzen für:

1. Unbehandelte `NSException` (bereits vorhanden)
2. **Fatale POSIX-Signale**, mindestens `SIGTRAP`, `SIGABRT`, `SIGSEGV`, `SIGBUS`, `SIGILL`, `SIGFPE`

Der Prozess stirbt weiter (kein Weiterlaufen nach dem Catch). Die Meldung geht **beim nächsten Start**, nicht im sterbenden Prozess per Netz.

## Begriffe (SSOT)

| Begriff | Bedeutung |
| --- | --- |
| **App-Absturz** | Prozessende durch unbehandelte `NSException` oder fatales POSIX-Signal |
| **Unbehandelte Ausnahme** | `NSException`, die `NSSetUncaughtExceptionHandler` erreicht |
| **Fataler Signal-Absturz** | u. a. Swift-Trap (`SIGTRAP` / `EXC_BREAKPOINT` aus `_assertionFailure`) und `abort`/`SIGABRT` |
| **Pending-Crash-Report** | Datei `pending-crash-report.txt` unter Application Support; nach Opt-in-Flush GitHub-Issue, sonst löschen |
| **Automatische Fehler-Issues** | Opt-in `AppSettingsKeys.reportErrorsToGitHub` und eingebettetes Token (`GitHubIssueAutoReport.isAutomaticReportingEnabled`) |

## Entscheidung (Alternativen)

| Ansatz | Nutzen | Kosten | Wahl |
| --- | --- | --- | --- |
| A POSIX-`sigaction` + bestehende Pending-Datei + `GitHubIssueReporter.flush` | Fängt den belegten SIGTRAP auch in lokalen Developer-ID-Builds | Handler muss async-signal-safe sein; Debugger nicht stören | **gewählt** |
| B nur MetricKit `MXCrashDiagnostic` | Plattform-API, reichere Stacks im Store | Liefert lokale Debug-/Developer-ID-Crashes oft nicht; hätte 21:37 nicht gemeldet | abgelehnt als alleiniger Weg |
| C `.ips` aus DiagnosticReports parsen | macOS hat den Apple-Report | iOS-Sandbox; PII (`crashReporterKey`); nicht die App-SSOT | abgelehnt |

MetricKit später ergänzen nur, wenn Store-Builds ohne Signal-Pfad nachweislich stumm bleiben. Nicht in v1.

## Architektur

Schicht: **ReisenAppCore** (`GitHubIssues/`) plus C-Target **ReisenCrashSignal** (SwiftPM erlaubt kein C+Swift im selben Target). Composition Root ruft weiter `GitHubIssueCrashCatcher.install()` aus `AppBootstrap.init` (macOS + iOS). Keine Domain-/UI-Parallelarchitektur.

```
install()
  ├── NSSetUncaughtExceptionHandler → Pending (Swift, SecretRedactor)
  └── sigaction(SIGTRAP, SIGABRT, …) → Pending (C / Darwin write, signal-safe)
        └── vorherigen Handler wiederherstellen / SIG_DFL + raise(sig)

nächster Start: flushPending() → GitHubIssueReporter.report(kind: .error, Titel aus Pending)
```

Kein neues Modul, kein dritter Reporter, keine parallele Fingerprint-Logik.

### Signal-Handler (Vertrag)

- Async-signal-safe: nur `open`/`write`/`close`/`backtrace`/`lseek`/`fstat`/`raise`/`signal`. Kein Swift-Heap, kein `FileManager`, kein `UserDefaults`, kein `SecretRedactor` im Handler.
- **Prepare mutiert keine Pending-Datei.** `prepare` speichert nur den Pfad in einem festen Puffer und das Opt-in-Flag (`sig_atomic_t`). Kein `open` mit `O_TRUNC`, kein Löschen, kein Anlegen der Datei. Eine Datei vom **vorherigen** Absturz muss `install()` am nächsten Start unangetastet lassen, bis `flushPending` sie gelesen hat.
- **Write öffnet erst im Handler** (bzw. in der testbaren Writer-Funktion): wenn `!opted_in` oder `already_written` → nicht schreiben, Datei nicht anlegen. Sonst `open`: Datei fehlt → `O_CREAT|O_WRONLY|O_EXCL`; Datei existiert bereits → **kein** Write (NSException oder alter Pending-Inhalt hat Vorrang).
- **Image-Snapshot** in `prepare` / `refresh_images` (nicht im Handler): `_dyld_*` + LC_UUID / `__TEXT`. `prepare` registriert `_dyld_register_func_for_add_image` → `refresh_images` bei später geladenen Images (WebKit). Handler liest nur die Tabelle und schreibt `Image +Offset`.
- **Breadcrumbs** aus öffentlichen `DiagnosticEvent`s (ohne `webview_created`/`webview_reparented` bei Erfolg); letzter `providerID` im Pending-Text.
- `write_current` darf nicht von einem schon offenen `pending_fd` abhängen, den Prepare nie setzt. Es öffnet aus `path_buf` oder bricht ohne Dateianlage ab.
- Nach erfolgreichem `NSException`-Pending `mark_written`, damit `SIGABRT` dieselbe Datei nicht mit ärmerem Signaltext überschreibt.
- Debugger (`P_TRACED`): fatale Signal-Handler **nicht** installieren (NSException-Handler bleibt).
- Nach dem Schreiben Default-Disposition und `raise(sig)` — die App bleibt abgestürzt.
- `SecretRedactor` nur auf dem Flush-Pfad. `pendingMessageForReport` redigiert den gelesenen Rohtext.

### Opt-in

Unverändert Default **aus**. Ohne Token kein automatischer Versand. Prepare/Write nutzen `GitHubIssueAutoReport.isAutomaticReportingEnabled()` (nicht implizit `true`).

Same-Session-Refresh: `GitHubIssueCrashCatcher.install()` (nur aus `AppBootstrap`) registriert `UserDefaults.didChangeNotification` und ruft `refreshFatalSignalOptIn()` auf. `SettingsView` bleibt bei `@AppStorage` — keine Kenntnis des C-Signalzustands.

### Issue

- `kind/error` + `source/in-app` (bestehende Labels)
- Ein Flush-Pfad; Titel aus Pending-Text: Signal → `[Fehler] SIGTRAP`, NSException → `GitHubIssueTitle.uncaughtException`
- Body: Signalname, `time_unix`, `pid`, letzter `provider`, Frames als `Adresse Image +Offset`, **nur** Images die im Stack vorkommen, Breadcrumbs + Diagnose-Tabelle
- Keine GitHub-Datei-Uploads (Issues-API kann keine Anhänge). Alles im Issue-Body, Limit 65536 Zeichen. Crash-Flush **ohne** zlib+Base64 (sonst verdrängt der Sync-Log-Blob Stack/Images beim Clamp).
- Diagnosezeile `Diagnosezeitpunkt | Neustart nach Absturz` — RAM/Thermal stammen vom Melde-Start, nicht vom Absturz
- Fingerprint: Signal + `Image +Offset` (ohne ASLR-Absolutadressen), damit gleiche Absturzstellen zusammenfallen
- Rate-Limit von `GitHubIssueReporter` unverändert

## Akzeptanz

1. Bei Opt-in fängt ein fataler `SIGTRAP` (ohne Debugger) einen Pending-Crash-Report mit Signalname, Image+Offset und UUID.
2. Ohne Opt-in entsteht keine Pending-Datei (wie heute bei NSException).
3. NSException-Pending wird nicht durch den nachfolgenden `SIGABRT` überschrieben.
4. Mit Debugger keine Signal-Handler-Installation.
5. `flushPending` sendet über `GitHubIssueReporter` und löscht die Datei bei Erfolg; ohne Token bleibt das bisherige Token-Fehler-Verhalten.
6. App terminiert nach dem Handler (kein Verschlucken des Absturzes).

## Out of Scope

- Absturzursache vom 21:37 (FoundationModels / CancellationError) fixen
- MetricKit, PLCrashReporter, Drittanbieter-Crashlytics
- Weiterlaufen nach dem Crash
- Versand im sterbenden Prozess
- Neue GitHub-Labels
- Änderung der Opt-in-Default-Politik

## Tesstrategie

Kein Test, der `SIGTRAP`/`abort` im Testprozess auslöst.

TDD: zuerst kompilierende Stubs (Writer gibt `false`, legt keine Datei an), RED = fachlicher Assert-Fail, dann GREEN.

C-Globals sind prozessweit: `reisen_crash_signal_reset_for_tests` vor jedem Signal-Test; Suite `.serialized`. Fachlich isolierte Tests bevorzugen `write_to_fd` ohne globale Prepare-State.

- `write_to_fd`: Signalname, `time_unix`, `pid`, optional `provider=`, Frames als `Adresse Image +Offset`, nur Images mit Frame, Breadcrumbs
- Opt-in false → **keine** Pending-Datei (nicht nur leer)
- `prepare(false)` dann `set_opted_in(true)` dann Write → Datei mit `SIGTRAP` (Same-Session-Refresh)
- Inverse: Opt-in, dann `set_opted_in(false)` → Write legt keine Datei an
- `mark_written` bzw. bereits existierende Datei → kein Überschreiben
- Debugger true → `install` false
- Flush-Read redigiert Rohtext
- bestehende NSException-Pending-Tests bleiben gültig
