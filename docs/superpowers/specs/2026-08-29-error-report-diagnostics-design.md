# Fehlerberichte: Umgebung + komprimierte Logs — Design

Datum: 2026-08-29  
Status: freigegeben (`/feature-dev`)

## Ziel

Öffentliche Fehler- und Feedback-Issues (Token-API, vorausgefüllte GitHub-URL, Auto-Report, Crash-Flush) enthalten **automatisch** die für die Analyse nötigen Gerätedaten und einen **begrenzten, geschwärzten, komprimierten** Auszug des App-Logs, **sofern** der Log existiert.

Die in der UI angezeigte Fehlermeldung bleibt die nutzerlesbare Kurzform. Logs und RAM-Zahlen gehören nicht in Banner, Sheets oder Screenshots.

## Ist-Zustand

`GitHubIssueDiagnostic` schreibt bereits: Art, Quelle, Meldeweg, GitHub-Nutzer, App-Version/Build, OS, Gerät, Locale, Zeitzone, Provider, Fingerprint.

`SyncLog` schreibt nach `Application Support/Reisen/sync-log.txt` (gleiche Basis wie `PersistenceBootstrap.supportDirectoryURL`), ohne Rotation, ohne Lese-API, ohne Anbindung an Issues. Ein Test verbietet bewusst `Sync-Log`/`logTail` im Issue-Body — das ändert diese Spec.

Fingerprint hängt nur an `kind` + normalisierter Meldung. Zusätzliche Diagnose darf **keine** neuen Issues für denselben Fehler erzeugen.

## Begriffe (SSOT)

| Begriff | Bedeutung |
| --- | --- |
| **Fehlermeldung (UI)** | `localizedDescription` / Sync-Text in Banner und Sheets. Unverändert. |
| **Fehlerbericht (Payload)** | Issue-Body bzw. Formularfeld `what`/`feedback`. Hier landen Diagnose und Log. |
| **Umgebungssnapshot** | Maschinenwerte zum Zeitpunkt des Reports, injizierbar in Tests. |
| **Log-Anhang** | Letzte N Rohbytes von `sync-log.txt`, geschwärzt, zlib+Base64, plus Klartext-Vorschau. |
| **nicht verfügbar** | Optionale API lieferte keinen Wert. Explizite Lücke, kein `0`/`""` als Erfolg. |
| **nicht vorhanden** | Logdatei fehlt. Eigene Zeile, kein leerer Codeblock als „Log“. |

## Anforderungen

### Umgebung — aufnehmen (nützlich und verfügbar)

| Feld | Quelle | Analyse |
| --- | --- | --- |
| Architektur | Compile-Arch (`arm64` / `x86_64`) | Rosetta, Native |
| RAM physisch | `ProcessInfo.physicalMemory` | große Catalogs / OOM-Nähe |
| Prozess-Fußabdruck | `task_info` / `task_vm_info.phys_footprint` | tatsächlicher Verbrauch |
| Freier Prozessspeicher | `os_proc_available_memory()` nur iOS | iOS Jetsam |
| Freier Volume-Platz | `volumeAvailableCapacityForImportantUsage` auf Support-Dir | Store/CloudKit-IO |
| Thermal | `ProcessInfo.thermalState` | Throttling, Timeouts |
| Energiesparmodus | `ProcessInfo.isLowPowerModeEnabled` | Background/Sync |
| Prozessoren | `processorCount` / `activeProcessorCount` | Last |
| System-Uptime | `ProcessInfo.systemUptime` | frischer Reboot |
| iCloud | `PersistenceBootstrap.isCloudKitEnabledByEnvironment()` | Store-Pfad |

Bestehende Felder (App, OS, Gerät, Locale, Zeitzone, Provider) bleiben.

Zahlen invariant formatieren (`1234 MiB`, `12.5 GiB`, `3600 s`), nicht lokalisiert.

### Umgebung — nicht aufnehmen

Computername, Login-User, Home-Pfad (Roh), IP, Seriennummer, `ProcessInfo.environment` (Secrets), Batterieprozent, Gerätename à la „Roberts iPad“, vollständige Volume-Pfade mit User-Segment.

### Logs

1. Quelle: nur `SyncLog` (`sync-log.txt`). Kein OS-unified-log-Export (TCC/Größe/PII).
2. Vor dem Anhang: `SecretRedactor.redact`.
3. Tail: letzte **16 384** Bytes der Datei (nach Lesen, vor Redact der Tail-Bytes als UTF-8-lossy).
4. Vorschau: letzte **12** Zeilen des geschwärzten Tails als Markdown-Codeblock (lesbar auf GitHub).
5. Komprimiert: derselbe geschwärzte Tail als **zlib** (`NSData.CompressionAlgorithm.zlib`) + **Base64**. Die Log-Tabelle nennt Dateigröße, Anhang roh und `truncated` (`ja`/`nein`).
6. Datei fehlt → `Sync-Log: nicht vorhanden`. Leere Datei → `Sync-Log: leer`.
7. Kompression schlägt fehl → Enum-Fall mit Vorschau **und** der Zeile `Kompression fehlgeschlagen`; `makeAttached` wirft nicht in den Report-Pfad. Issue trotzdem senden.
8. Rotation beim **Schreiben** (`append`): Datei > **262 144** Bytes → auf letzte **65 536** Bytes kürzen. Verhindert unbegrenztes Wachstum.

Crash-Stack bleibt in der Meldung (bestehender Catcher). Der Log-Anhang ist zusätzlich, nicht Ersatz.

### Kanäle

| Kanal | Umgebungstabelle | Log-Vorschau | zlib-Blob |
| --- | --- | --- | --- |
| Token-API `GitHubIssueDiagnostic.body` | vollständig | ja | ja |
| Repeat-Kommentar | kompakt (RAM, Thermal, Low Power, Disk, iCloud) | letzte 5 Zeilen | nein |
| URL-Formular `collectedFormFieldContent` | vollständig (Tabelle) | nein (Budget) | nein |
| UI-Banner | nein | nein | nein |

URL-Truncation (`maxBodyCharacterCount` 6000) bleibt. **Vorrang der Tabelle:** `collectedFormFieldContent` baut zuerst die Diagnose-Tabelle (ohne zlib, ohne `## Sync-Log`). Die Meldung wird so gekürzt, dass Tabelle + Trennlinie immer in das Zeichenbudget passen. `GitHubIssueNewIssueURL.formFieldValueForQuery` darf nicht mehr das Ende (die Tabelle) abschneiden, während die Meldung vollständig bleibt.

Fingerprint unverändert.

## Schicht-Landung

| Unit | Modul | Verantwortung |
| --- | --- | --- |
| `GitHubIssueDiagnostic` | ReisenAppCore | Tabelle + Sektionen, SSOT Issue-Text |
| `RuntimeEnvironmentSnapshot` | ReisenAppCore | Live-Collect + Format; optionale Felder `Optional` |
| `SyncLog` | ReisenAppCore | append, rotate, `recentTail`; URL über `PersistenceBootstrap.supportDirectoryURL()` |
| `DiagnosticLogCompressor` | ReisenAppCore | zlib+Base64; testbar ohne Datei |
| `SecretRedactor` | ReisenAppCore | unverändert, Pflicht vor Anhang |
| Privacy-HTML DE/EN | `docs/legal/` | Meldeinhalt = Wirklichkeit |
| `docs/ci/app-store-connect.md` | Docs | Nutrition-Label-Zeile Diagnosedaten |

Kein neues SPM-Target. Domain bleibt frei von Darwin/`task_info`. UI (`ReisenSharedUI`) ändert keine Banner-Texte.

`GitHubIssueReporter.report` und Crash-Flush brauchen keine zweite Sammelstelle: Collect passiert in `deviceSnapshot` / Body-Bau, denselben Einstieg wie heute.

## Datenfluss

```
Fehler (UI-Text)
    │
    ├─► SyncStore.errorMessage          (unverändert, nutzerlesbar)
    │
    └─► GitHubIssueReporter.report / NewIssueURL.compose
            │
            ├─ RuntimeEnvironmentSnapshot.collect()   (optionale APIs → Optional)
            ├─ SyncLog.recentTail → SecretRedactor → Compressor
            └─ GitHubIssueDiagnostic.body / collectedFormFieldContent
```

Ownership: Collect zum Report-Zeitpunkt (nicht beim ersten UI-Fehler), damit Auto-Report und manuelles Melden denselben Stand haben wie der Klick.

## Fehlerbehandlung

- Collect darf den Report nicht abbrechen. Fehlende optionale Werte → „nicht verfügbar“.
- Log-IO-Fehler → `Sync-Log: nicht lesbar` plus `localizedDescription` geschwärzt, Issue trotzdem senden.
- Keine stillen Fallbacks (`?? 0` für RAM). `physicalMemory` ist immer da (`UInt64`); Fußabdruck/Disk/available sind optional.

## Datenschutz

Payload bleibt **öffentlich**. Deshalb: Redact, Tail-Limit, keine Env-Vars, Privacy-Texte DE+EN anpassen (Arbeitsspeicher, Speicherplatz, Thermal/Energiesparmodus, Architektur, gekürztes/komprimiertes Sync-Log).

`PrivacyInfo.xcprivacy`: `NSPrivacyCollectedDataTypeOtherDiagnosticData` bleibt; kein neuer Datentyp.

Rechtsgrundlage unverändert: manuell berechtigtes Interesse / Auto-Report Einwilligung.

## Ansätze (eine Wahl)

| | Ansatz | Vorteil | Nachteil |
| --- | --- | --- | --- |
| A | Nur Tabelle um RAM/Disk/Thermal | klein | ohne Log oft nicht reproduzierbar |
| **B** | **Tabelle + begrenzter zlib-Tail + Vorschau (empfohlen)** | lesbar und kompakt, URL-sicher | etwas mehr Code |
| C | UI-Fehlertext anreichern | Copy aus der App | PII in Screenshots, HIG-Lärm |

**Wahl B:** Analyse passiert auf GitHub; die App bleibt ruhig. Komprimiert = zlib des Tails, nicht „ganzes File gzip“.

## Out of Scope

- Unified Logging / Console.app-Export
- Neuer Settings-Toggle (bestehendes Auto-Report + manuelles Melden)
- Sentry/Telemetry-SDK
- Log-Inhalte in `errorMessage`
- Ändern der Fingerprint-Formel
- Live-Geräte-Korpus in CI (`open_gaps`)

## Schnittstellen-Inventar

Kein `port-only`. Kein Profil `unstructured_input`.

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| error-report-entry | entry | bestehende Melde-Buttons / Auto-Report / Crash-Flush | Body-Tests am Reporter- und URL-Einstieg |
| issue-opt-in-capability | capability | Opt-in + PAT; Privacy-HTML | LegalPrivacyContentTests; ASC-Doku |
| runtime-env-adapter | adapter | optionale Darwin/ProcessInfo-APIs | Snapshot-Tests nil vs. Wert, kein Crash |
| diagnostic-contract | contract | Felder, Limits, zlib-Format, Fingerprint | Unit-Tests |
| neighbor-diagnostic-ssot | neighbor | ein Diagnostic-Builder | kein zweiter Pfad |
| live-device-corpus | corpus | echte Logs | `open_gaps` — kein CI-Korpus |

## Akzeptanz

1. API-Issue-Body enthält neue Tabellenzeilen und `## Sync-Log` mit Vorschau + zlib-Block **oder** expliziter Lücke.
2. Geschwärzte Secrets im Log-Tail (gleiches Redact wie Meldung).
3. URL-Formular enthält Tabelle, **keinen** zlib-Blob; bleibt ≤ URL-Limits.
4. Fingerprint identisch für gleiche Meldung unabhängig von RAM/Log.
5. Fehlende optionale Messwerte stehen als „nicht verfügbar“, nicht als 0.
6. Privacy DE+EN beschreiben die neuen Daten.
7. UI-Banner unverändert ohne Log-Dump.

## Teststrategie

- Injizierter `RuntimeEnvironmentSnapshot` und injizierte Log-URL (kein Live-sysctl in Tabellen-Tests).
- Compressor: Round-Trip zlib; Preview-Zeilenzahl.
- `SyncLog.append` Rotation mit Temp-Datei.
- Bestehenden Test `githubIssueDiagnostic_includesUnredactedErrorMessage` umkehren: Sync-Log-Sektion **mit** injiziertem Tail.
- URL-Tests: `what`/`feedback` ohne `eJ`/`zlib` typische Blob-Marker der Fixture.
- Privacy-Needles: `Arbeitsspeicher` / `memory`, `Sync-Log` / `sync log`.
