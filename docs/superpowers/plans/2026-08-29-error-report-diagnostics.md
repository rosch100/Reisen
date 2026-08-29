# Error-Report-Diagnostik Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Tasks gekoppelt, Parent = Implementer) oder subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitHub-Fehlerberichte um injizierbare Umgebungsdaten und einen geschwärzten, zlib-komprimierten Sync-Log-Tail erweitern, ohne UI-Banner und ohne Fingerprint-Änderung.

**Architecture:** Alles in `ReisenAppCore` am bestehenden `GitHubIssueDiagnostic`-Einstieg. `RuntimeEnvironmentSnapshot` sammelt optionale Darwin/ProcessInfo-Werte. `SyncLog` liest/rotiert dieselbe Datei wie bisher. `DiagnosticLogCompressor` macht zlib+Base64. Token-API-Body bekommt Vorschau+Blob; URL-Formular nur Tabelle; Repeat-Kommentar kompakt ohne Blob.

**Tech Stack:** Swift 6, Foundation `Data.compressed(using: .zlib)`, Darwin `task_info`, Swift Testing, `SecretRedactor`.

## Global Constraints

- Schicht: nur `ReisenAppCore` (+ Privacy-HTML/ASC-Doku); Domain ohne Darwin.
- Keine Dummy-Werte: optionale Messwerte `nil` → Text `nicht verfügbar`.
- `SecretRedactor.redact` vor jedem Log-Anhang.
- Fingerprint bleibt `GitHubIssueFingerprint.hex(kind:message:)`.
- UI-`errorMessage` unverändert.
- Öffentliche Issues: keine Env-Vars, keine User-Pfade roh.
- Limits: Tail 16384 Bytes, Preview 12 Zeilen, Rotation 262144→65536, Kommentar-Preview 5 Zeilen.

---

### Task 1: Umgebungssnapshot und Diagnosetabelle

**Files:**
- Create: `Sources/ReisenAppCore/GitHubIssues/RuntimeEnvironmentSnapshot.swift`
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueDiagnostic.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift` (`diagnosticBody` Helper + Tests)

**Interfaces:**
- Consumes: bestehendes `GitHubIssueDiagnostic.DeviceDiagnostics` ohne Log
- Produces: `RuntimeEnvironmentSnapshot` (siehe Code), `DeviceDiagnostics.environment: RuntimeEnvironmentSnapshot`, Tabellenzeilen laut Spec

- [ ] **Step 1: Write the failing test**

In `Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift` Helper `diagnosticBody` um `environment:` erweitern (Default-Fixture unten). Neuer Test:

```swift
@Test func githubIssueDiagnostic_includesRuntimeEnvironmentRows() {
    let body = diagnosticBody(
        environment: RuntimeEnvironmentSnapshot(
            architecture: "arm64",
            physicalMemoryBytes: 16 * 1024 * 1024 * 1024,
            processFootprintBytes: 200 * 1024 * 1024,
            availableMemoryBytes: 800 * 1024 * 1024,
            volumeAvailableBytes: 20 * 1024 * 1024 * 1024,
            thermalState: "nominal",
            lowPowerMode: false,
            processorCount: 10,
            activeProcessorCount: 8,
            systemUptimeSeconds: 3600,
            cloudKitEnabled: true
        )
    )
    #expect(body.contains("| Architektur | arm64 |"))
    #expect(body.contains("| RAM physisch | 16384 MiB |"))
    #expect(body.contains("| Prozess-Fußabdruck | 200 MiB |"))
    #expect(body.contains("| Freier Prozessspeicher | 800 MiB |"))
    #expect(body.contains("| Freier Volume-Platz | 20.0 GiB |"))
    #expect(body.contains("| Thermal | nominal |"))
    #expect(body.contains("| Energiesparmodus | nein |"))
    #expect(body.contains("| Prozessoren | 8/10 |"))
    #expect(body.contains("| System-Uptime | 3600 s |"))
    #expect(body.contains("| iCloud | an |"))
}

@Test func githubIssueDiagnostic_marksMissingOptionalEnvironmentAsUnavailable() {
    let body = diagnosticBody(
        environment: RuntimeEnvironmentSnapshot(
            architecture: "arm64",
            physicalMemoryBytes: 8 * 1024 * 1024 * 1024,
            processFootprintBytes: nil,
            availableMemoryBytes: nil,
            volumeAvailableBytes: nil,
            thermalState: "nicht verfügbar",
            lowPowerMode: false,
            processorCount: 8,
            activeProcessorCount: 8,
            systemUptimeSeconds: 10,
            cloudKitEnabled: false
        )
    )
    #expect(body.contains("| Prozess-Fußabdruck | nicht verfügbar |"))
    #expect(body.contains("| Freier Prozessspeicher | nicht verfügbar |"))
    #expect(body.contains("| Freier Volume-Platz | nicht verfügbar |"))
    #expect(body.contains("| iCloud | aus |"))
    #expect(!body.contains("| Prozess-Fußabdruck | 0 MiB |"))
}
```

Default im Helper: dieselbe Fixture wie der erste Test (nicht `nil`).

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/roschmac/Entwicklung/Reisen/.worktrees/feat-error-diagnostics
swift test --filter githubIssueDiagnostic_includesRuntimeEnvironmentRows --filter githubIssueDiagnostic_marksMissingOptionalEnvironmentAsUnavailable
```

Expected: FAIL (Typ `RuntimeEnvironmentSnapshot` fehlt oder Tabelle ohne neue Zeilen).

- [ ] **Step 3: Write minimal implementation**

`Sources/ReisenAppCore/GitHubIssues/RuntimeEnvironmentSnapshot.swift`:

```swift
import Foundation

struct RuntimeEnvironmentSnapshot: Equatable, Sendable {
    var architecture: String
    var physicalMemoryBytes: UInt64
    var processFootprintBytes: UInt64?
    var availableMemoryBytes: UInt64?
    var volumeAvailableBytes: Int64?
    var thermalState: String
    var lowPowerMode: Bool
    var processorCount: Int
    var activeProcessorCount: Int
    var systemUptimeSeconds: TimeInterval
    var cloudKitEnabled: Bool

    func tableRows() -> String {
        """
        | Architektur | \(architecture) |
        | RAM physisch | \(Self.mebibytes(physicalMemoryBytes)) |
        | Prozess-Fußabdruck | \(Self.optionalMebibytes(processFootprintBytes)) |
        | Freier Prozessspeicher | \(Self.optionalMebibytes(availableMemoryBytes)) |
        | Freier Volume-Platz | \(Self.optionalGibibytes(volumeAvailableBytes)) |
        | Thermal | \(thermalState) |
        | Energiesparmodus | \(lowPowerMode ? "ja" : "nein") |
        | Prozessoren | \(activeProcessorCount)/\(processorCount) |
        | System-Uptime | \(Int(systemUptimeSeconds.rounded())) s |
        | iCloud | \(cloudKitEnabled ? "an" : "aus") |
        """
    }

    static func mebibytes(_ bytes: UInt64) -> String {
        "\(bytes / (1024 * 1024)) MiB"
    }

    static func optionalMebibytes(_ bytes: UInt64?) -> String {
        guard let bytes else { return "nicht verfügbar" }
        return mebibytes(bytes)
    }

    static func optionalGibibytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "nicht verfügbar" }
        let gib = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        return String(format: "%.1f GiB", gib)
    }
}
```

`DeviceDiagnostics` um `environment: RuntimeEnvironmentSnapshot` erweitern. `diagnosticTable` hängt `environment.tableRows()` vor der Provider-Zeile ein (Provider-Zeile bleibt letzte Datenzeile vor Fingerprint).

`deviceSnapshot` setzt vorerst ein Fixture-gleiches Live-Collect **noch nicht** — Live-Collect in Task 3. Für Kompilieren von `deviceSnapshot` eine `RuntimeEnvironmentSnapshot.live()`-Methode anlegen, die Compiliert, aber in Task 1 dürfen die **Tabellen-Tests** nur die injizierte Fixture nutzen.

```swift
static func live() -> RuntimeEnvironmentSnapshot {
    let info = ProcessInfo.processInfo
    return RuntimeEnvironmentSnapshot(
        architecture: currentArchitecture(),
        physicalMemoryBytes: info.physicalMemory,
        processFootprintBytes: nil,
        availableMemoryBytes: nil,
        volumeAvailableBytes: nil,
        thermalState: thermalLabel(info.thermalState),
        lowPowerMode: info.isLowPowerModeEnabled,
        processorCount: info.processorCount,
        activeProcessorCount: info.activeProcessorCount,
        systemUptimeSeconds: info.systemUptime,
        cloudKitEnabled: PersistenceBootstrap.isCloudKitEnabledByEnvironment()
    )
}

private static func currentArchitecture() -> String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x86_64"
    #else
    return "unbekannt"
    #endif
}

private static func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: "nominal"
    case .fair: "fair"
    case .serious: "serious"
    case .critical: "critical"
    @unknown default: "nicht verfügbar"
    }
}
```

`GitHubIssueDiagnostic` braucht `import ReisenData` für `PersistenceBootstrap` — Target hängt bereits an ReisenData.

Helper `diagnosticBody` in Tests: neues Pflichtfeld `environment:` mit Default-Fixture (erster Test).

- [ ] **Step 4: Run test to verify it passes**

Dieselben `--filter` wie Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/GitHubIssues/RuntimeEnvironmentSnapshot.swift \
  Sources/ReisenAppCore/GitHubIssues/GitHubIssueDiagnostic.swift \
  Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift
git commit -m "$(cat <<'EOF'
feat: Umgebungssnapshot in GitHub-Fehlerdiagnose aufnehmen

Fehleranalyse braucht RAM, Thermal und Speicherplatz neben OS/Gerät.
EOF
)"
```

---

### Task 2: SyncLog-Tail, Rotation, zlib-Anhang

**Files:**
- Create: `Sources/ReisenAppCore/GitHubIssues/DiagnosticLogCompressor.swift`
- Create: `Tests/ReisenAppCoreTests/DiagnosticLogCompressorTests.swift`
- Create: `Tests/ReisenAppCoreTests/SyncLogTests.swift`
- Modify: `Sources/ReisenAppCore/SyncStore.swift` (`SyncLog`)
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueDiagnostic.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift`

**Interfaces:**
- Consumes: `RuntimeEnvironmentSnapshot` aus Task 1; `SecretRedactor.redact`
- Produces: `DiagnosticLogAttachment` (`missing` / `empty` / `unreadable(String)` / `compressionFailed(preview:)` / `attached(...)`). `body`/`collectedFormFieldContent` behalten Default-Parameter (`logAttachment: .missing`), damit Task-2 ohne Reporter-Änderungen kompiliert.

- [ ] **Step 1: Write the failing tests**

`Tests/ReisenAppCoreTests/DiagnosticLogCompressorTests.swift`:

```swift
import Testing
import Foundation
@testable import ReisenAppCore

@Test func diagnosticLogCompressor_roundTripsUTF8() throws {
    let raw = "line-a\nline-b\n"
    let encoded = try DiagnosticLogCompressor.zlibBase64(raw)
    #expect(!encoded.isEmpty)
    let decoded = try DiagnosticLogCompressor.decodeUTF8(fromZlibBase64: encoded)
    #expect(decoded == raw)
}

@Test func diagnosticLogCompressor_previewTakesLastLines() {
    let text = (1...20).map { "z\($0)" }.joined(separator: "\n")
    let preview = DiagnosticLogCompressor.preview(from: text, lastLineCount: 12)
    #expect(preview.split(separator: "\n").count == 12)
    #expect(preview.contains("z20"))
    #expect(!preview.contains("z1\n"))
}
```

`Tests/ReisenAppCoreTests/SyncLogTests.swift`: Temp-Datei, `append` schreibt ISO-Zeile; Datei größer als `SyncLog.maxFileBytes` wird auf `keepBytes` gekürzt; `recentTail` liefert Suffix.

`GitHubIssueReporterTests.swift` — bestehenden Test ersetzen:

```swift
@Test func githubIssueDiagnostic_includesRedactedCompressedSyncLog() throws {
    let tail = "ok line\nsecret gast@domain.de\n"
    let attachment = try DiagnosticLogAttachment.makeAttached(
        redactedTail: SecretRedactor.redact(tail),
        fileByteCount: 80,
        truncated: false
    )
    let body = diagnosticBody(logAttachment: attachment, includeCompressedLog: true)
    #expect(body.contains("## Sync-Log"))
    #expect(body.contains("truncated: nein"))
    #expect(body.contains("ok line"))
    #expect(!body.contains("gast@domain.de"))
    #expect(body.contains("[redacted]"))
    #expect(body.contains("zlib+Base64"))
}

@Test func githubIssueDiagnostic_syncLogMissingIsExplicit() {
    let body = diagnosticBody(logAttachment: .missing, includeCompressedLog: true)
    #expect(body.contains("Sync-Log: nicht vorhanden"))
    #expect(!body.contains("zlib+Base64"))
}

@Test func githubIssueDiagnostic_urlFormOmitsZlibBlob() throws {
    let attachment = try DiagnosticLogAttachment.makeAttached(
        redactedTail: "only-preview\n",
        fileByteCount: 12,
        truncated: false
    )
    let field = GitHubIssueDiagnostic.collectedFormFieldContent(
        kind: .error,
        message: "Timeout",
        providerID: nil,
        origin: .embeddedToken(attributedUsername: nil),
        environment: .testFixture,
        logAttachment: attachment
    )
    #expect(field.contains("| Architektur |"))
    #expect(!field.contains("zlib+Base64"))
    #expect(!field.contains("## Sync-Log"))
}
```

`collectedFormFieldContent` bleibt mit Defaults kompatibel. Tests übergeben Snapshot/Attachment explizit.

`DiagnosticLogAttachment.makeAttached` wirft **nicht**. Kompression fehlgeschlagen → `.compressionFailed(preview:)` mit Zeile `Kompression fehlgeschlagen`.

Zusätzlich Test `githubIssueDiagnostic_compressionFailedKeepsPreview` (Vorschau + `Kompression fehlgeschlagen`, kein zlib) und `githubIssueNewIssueURL_longMessageKeepsEnvironmentTable` (12 000er Meldung, Tabelle `| Architektur |` bleibt, `value.count <= maxBodyCharacterCount`).

`collectedFormFieldContent` kürzt die **Meldung**, nicht die Tabelle.

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter diagnosticLogCompressor --filter githubIssueDiagnostic_includesRedactedCompressedSyncLog --filter githubIssueDiagnostic_syncLogMissingIsExplicit --filter githubIssueDiagnostic_urlFormOmitsZlibBlob --filter syncLog
```

Expected: FAIL (fehlende Typen).

- [ ] **Step 3: Write minimal implementation**

`DiagnosticLogCompressor.swift`:

```swift
import Foundation

enum DiagnosticLogCompressor {
    static func zlibBase64(_ text: String) throws -> String {
        let data = Data(text.utf8)
        let compressed = try data.compressed(using: .zlib)
        return compressed.base64EncodedString()
    }

    static func decodeUTF8(fromZlibBase64 encoded: String) throws -> String {
        guard let data = Data(base64Encoded: encoded) else {
            throw DiagnosticLogCompressorError.invalidBase64
        }
        let raw = try data.decompressed(using: .zlib)
        guard let text = String(data: raw, encoding: .utf8) else {
            throw DiagnosticLogCompressorError.invalidUTF8
        }
        return text
    }

    static func preview(from text: String, lastLineCount: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let slice = lines.suffix(lastLineCount)
        return slice.joined(separator: "\n")
    }
}

enum DiagnosticLogCompressorError: Error {
    case invalidBase64
    case invalidUTF8
}
```

`DiagnosticLogAttachment` in derselben Datei oder in `GitHubIssueDiagnostic.swift`:

```swift
enum DiagnosticLogAttachment: Equatable, Sendable {
    case missing
    case empty
    case unreadable(String)
    case compressionFailed(preview: String)
    case attached(
        preview: String,
        zlibBase64: String,
        rawByteCount: Int,
        fileByteCount: Int,
        truncated: Bool
    )

    static let attachMaxRawBytes = 16_384
    static let previewLineCount = 12
    static let commentPreviewLineCount = 5

    static func makeAttached(
        redactedTail: String,
        fileByteCount: Int,
        truncated: Bool
    ) -> DiagnosticLogAttachment {
        let preview = DiagnosticLogCompressor.preview(
            from: redactedTail,
            lastLineCount: previewLineCount
        )
        do {
            let blob = try DiagnosticLogCompressor.zlibBase64(redactedTail)
            return .attached(
                preview: preview,
                zlibBase64: blob,
                rawByteCount: redactedTail.utf8.count,
                fileByteCount: fileByteCount,
                truncated: truncated
            )
        } catch {
            return .compressionFailed(preview: preview)
        }
    }

    func markdownSection(includeCompressedLog: Bool) -> String {
        switch self {
        case .missing:
            return "\n## Sync-Log\nSync-Log: nicht vorhanden\n"
        case .empty:
            return "\n## Sync-Log\nSync-Log: leer\n"
        case .unreadable(let detail):
            return "\n## Sync-Log\nSync-Log: nicht lesbar\n\(SecretRedactor.redact(detail))\n"
        case .compressionFailed(let preview):
            return """

            ## Sync-Log
            ### Vorschau (letzte \(Self.previewLineCount) Zeilen, geschwärzt)
            ```
            \(preview)
            ```
            Kompression fehlgeschlagen
            """
        case .attached(let preview, let blob, let raw, let file, let truncated):
            var text = """

            ## Sync-Log
            | Feld | Wert |
            | --- | --- |
            | Dateigröße | \(file) B |
            | Anhang roh | \(raw) B |
            | truncated | \(truncated ? "ja" : "nein") |

            ### Vorschau (letzte \(Self.previewLineCount) Zeilen, geschwärzt)
            ```
            \(preview)
            ```
            """
            if includeCompressedLog {
                text += """

                ### zlib+Base64
                ```
                \(blob)
                ```
                """
            }
            return text
        }
    }
}
```

`SyncLog` in `SyncStore.swift` ersetzen/erweitern:

```swift
public enum SyncLog {
    static let maxFileBytes = 262_144
    static let keepBytes = 65_536

    static func fileURL() -> URL? {
        PersistenceBootstrap.supportDirectoryURL()?
            .appendingPathComponent("sync-log.txt")
    }

    public static func append(_ line: String) {
        append(line, to: fileURL(), now: Date())
    }

    static func append(_ line: String, to url: URL?, now: Date) {
        guard let logURL = url else { return }
        // bestehendes Schreiben + danach rotateIfNeeded(at: logURL)
    }

    static func recentTail(maxBytes: Int = DiagnosticLogAttachment.attachMaxRawBytes, fileURL: URL? = nil) -> DiagnosticLogAttachment {
        guard let url = fileURL ?? Self.fileURL() else { return .missing }
        // fehlt → missing; leer → empty; read suffix; truncated = fileSize > maxBytes
        // redact; makeAttached (nie throw) oder unreadable
    }
}
```

`append` muss `import ReisenData` — `SyncStore.swift` importiert es bereits.

`body(..., includeCompressedLog: Bool = true)` hängt `logAttachment.markdownSection`. `collectedFormFieldContent` setzt `includeCompressedLog: false` und **keine** `## Sync-Log`-Sektion. Neue Parameter mit Defaults, damit Reporter/URL in Task 2 kompilieren.

`collectedFormFieldContent`: `table = diagnosticTable(...)`; Meldung auf `max(0, GitHubIssueNewIssueURL.maxBodyCharacterCount - table.count - 10)` kürzen; Ausgabe `meldung + "\\n\\n---\\n\\n" + table`.

Bestehenden Test `githubIssueDiagnostic_includesUnredactedErrorMessage` so anpassen, dass er `logAttachment: .missing` nutzt **oder** die Negativ-Asserts `Sync-Log`/`logTail` entfernt, weil der Default-Body sonst die Sektion hat. Default im Helper: `.missing` plus `includeCompressedLog: true`, damit alte Tests die explizite Lücke sehen (`contains("nicht vorhanden")` nur wo gewollt). Alte Tests, die `!body.contains("Sync-Log")` haben, **löschen** und durch die neuen ersetzen.

- [ ] **Step 4: Run tests to verify they pass**

Dieselben Filter. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/GitHubIssues/DiagnosticLogCompressor.swift \
  Sources/ReisenAppCore/SyncStore.swift \
  Sources/ReisenAppCore/GitHubIssues/GitHubIssueDiagnostic.swift \
  Tests/ReisenAppCoreTests/DiagnosticLogCompressorTests.swift \
  Tests/ReisenAppCoreTests/SyncLogTests.swift \
  Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift
git commit -m "$(cat <<'EOF'
feat: geschwärzten Sync-Log-Tail komprimiert an Fehlerberichte anhängen

Issue-Bodies brauchen den letzten Log-Kontext ohne unbegrenzte Dateien und ohne Secrets.
EOF
)"
```

---

### Task 3: Live-Collect, Reporter-Kommentar, optionale Darwin-APIs

**Files:**
- Modify: `Sources/ReisenAppCore/GitHubIssues/RuntimeEnvironmentSnapshot.swift` (`live()`: footprint, Disk, iOS available memory)
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueDiagnostic.swift` (`deviceSnapshot` sammelt live + `SyncLog.recentTail()`)
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueReporter.swift` (`commentBody` kompakt)
- Create: `Tests/ReisenAppCoreTests/RuntimeEnvironmentSnapshotTests.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift` (Reporter sendet Tabelle; Kommentar ohne zlib)
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueNewIssueURLTests.swift` (kein zlib in `what`)

**Interfaces:**
- Consumes: `RuntimeEnvironmentSnapshot.live()`, `SyncLog.recentTail()`, `DiagnosticLogAttachment.markdownSection(includeCompressedLog:)`
- Produces: `deviceSnapshot` liefert Live-Werte; `commentBody(kind:message:environment:logAttachment:)`; optionale APIs crash-frei

- [ ] **Step 1: Write the failing tests**

```swift
@Test func runtimeEnvironmentSnapshot_liveAlwaysHasPhysicalMemoryAndArchitecture() {
    let snap = RuntimeEnvironmentSnapshot.live()
    #expect(snap.physicalMemoryBytes > 0)
    #expect(snap.architecture == "arm64" || snap.architecture == "x86_64")
    #expect(snap.thermalState == "nominal"
        || snap.thermalState == "fair"
        || snap.thermalState == "serious"
        || snap.thermalState == "critical"
        || snap.thermalState == "nicht verfügbar")
}

@Test func githubIssueReporter_createBodyIncludesArchitectureRow() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "tok" },
        persistenceURL: nil
    )
    _ = try await reporter.report(kind: .error, message: "Provider timeout konkret", providerID: .opodo)
    let body = try #require(client.lastCreate?.body)
    #expect(body.contains("| Architektur |"))
    #expect(body.contains("## Sync-Log"))
}

@Test func githubIssueReporter_repeatCommentOmitsZlibBlob() async throws {
    let client = MockGitHubIssues()
    client.openFingerprints = [
        GitHubIssueFingerprint.hex(kind: .error, message: "gleiche meldung"): 7
    ]
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "tok" },
        persistenceURL: nil
    )
    _ = try await reporter.report(kind: .error, message: "gleiche meldung", providerID: nil)
    let comment = try #require(client.lastCommentBody)
    #expect(!comment.contains("zlib+Base64"))
    #expect(comment.contains("| RAM physisch |"))
}

@Test func runtimeEnvironmentSnapshot_kernFailureYieldsNilFootprint() {
    #expect(RuntimeEnvironmentSnapshot.footprintBytes(kernReturn: KERN_FAILURE, physFootprint: 99) == nil)
    #expect(RuntimeEnvironmentSnapshot.footprintBytes(kernReturn: KERN_SUCCESS, physFootprint: 99) == 99)
}

@Test func runtimeEnvironmentSnapshot_missingVolumeCapacityIsNil() {
    #expect(RuntimeEnvironmentSnapshot.volumeBytes(importantUsage: nil) == nil)
    #expect(RuntimeEnvironmentSnapshot.volumeBytes(importantUsage: 5) == 5)
}
```

`MockGitHubIssues.comment` speichert `lastCommentBody`.

AC7: `assignError` bleibt `errorMessage = mapped.localizedDescription`. Test `githubIssueDiagnostic_payloadIsSeparateFromRawMessage`: Roh-Meldung enthält kein `Sync-Log` und kein `MiB`; der Body schon.

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter runtimeEnvironmentSnapshot_liveAlwaysHasPhysicalMemoryAndArchitecture --filter githubIssueReporter_createBodyIncludesArchitectureRow --filter githubIssueReporter_repeatCommentOmitsZlibBlob
```

Expected: FAIL (live footprint/disk fehlen; comment noch alt).

- [ ] **Step 3: Write minimal implementation**

`RuntimeEnvironmentSnapshot.live()`:

- `processFootprintBytes`: `task_info(mach_task_self_, task_vm_info, …)` → `phys_footprint`; bei `KERN_SUCCESS` sonst `nil` (nicht 0 als Erfolg wenn info fehlschlägt).
- `volumeAvailableBytes`: `URL` Support-Dir `resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])`.
- iOS: `availableMemoryBytes = UInt64(os_proc_available_memory())` wenn > 0, sonst `nil`. macOS: `nil`.

`deviceSnapshot`:

```swift
static func deviceSnapshot(kind: GitHubIssueKind, redactedMessage: String) -> DeviceDiagnostics {
    DeviceDiagnostics(
        fingerprint: GitHubIssueFingerprint.hex(kind: kind, message: redactedMessage),
        appVersion: ...,
        ...
        environment: .live(),
        logAttachment: SyncLog.recentTail()
    )
}
```

`body`/`collectedFormFieldContent` nutzen `diagnostics.logAttachment` und `includeCompressedLog`.

`commentBody`:

```swift
private func commentBody(kind: GitHubIssueKind, message: String) -> String {
    let env = RuntimeEnvironmentSnapshot.live()
    let log = SyncLog.recentTail()
    let logBlock: String
    switch log {
    case .attached(let preview, _, _, _, _), .compressionFailed(let preview):
        let lines = DiagnosticLogCompressor.preview(
            from: preview,
            lastLineCount: DiagnosticLogAttachment.commentPreviewLineCount
        )
        logBlock = "```\n\(lines)\n```"
    case .missing:
        logBlock = "Sync-Log: nicht vorhanden"
    case .empty:
        logBlock = "Sync-Log: leer"
    case .unreadable(let detail):
        logBlock = "Sync-Log: nicht lesbar\n\(SecretRedactor.redact(detail))"
    }
    return """
    Erneuter \(kind.repeatReportLabel) (\(ISO8601DateFormatter().string(from: now()))):

    ```
    \(message)
    ```

    | RAM physisch | \(RuntimeEnvironmentSnapshot.mebibytes(env.physicalMemoryBytes)) |
    | Thermal | \(env.thermalState) |
    | Energiesparmodus | \(env.lowPowerMode ? "ja" : "nein") |
    | Freier Volume-Platz | \(RuntimeEnvironmentSnapshot.optionalGibibytes(env.volumeAvailableBytes)) |
    | iCloud | \(env.cloudKitEnabled ? "an" : "aus") |

    \(logBlock)
    """
}
```

`RuntimeEnvironmentSnapshot.footprintBytes(kernReturn:physFootprint:)` und `volumeBytes(importantUsage:)` sind Mapper für Adapter-Tests (kein Dummy-0).

`GitHubIssueNewIssueURL` unverändert in der Call-Kette, wenn `collectedFormFieldContent` die neuen Parameter intern mit `deviceSnapshot` füllt.

- [ ] **Step 4: Run tests to verify they pass**

Filter aus Step 2 plus `GitHubIssueNewIssueURL`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/GitHubIssues \
  Tests/ReisenAppCoreTests/RuntimeEnvironmentSnapshotTests.swift \
  Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift \
  Tests/ReisenAppCoreTests/GitHubIssueNewIssueURLTests.swift
git commit -m "$(cat <<'EOF'
feat: Live-Umgebung und kompakte Repeat-Kommentare an Issue-Reports koppeln

Reports sollen denselben Collect-Pfad nutzen; URL und Kommentare bleiben größenbegrenzt.
EOF
)"
```

---

### Task 4: Datenschutz und ASC-Abgleich

**Files:**
- Modify: `docs/legal/privacy.html` (Absatz Feedback und Fehler)
- Modify: `docs/legal/en/privacy.html` (entsprechender Absatz)
- Modify: `Tests/ReisenDomainTests/LegalPrivacyContentTests.swift`
- Modify: `docs/ci/app-store-connect.md` (Zeile Sonstige Diagnosedaten)

**Interfaces:**
- Consumes: Spec-Liste der gemeldeten Felder
- Produces: Privacy-Text = tatsächliches Meldeverhalten

- [ ] **Step 1: Write the failing test**

In `LegalPrivacyContentTests` Needles ergänzen:

DE: `Arbeitsspeicher`, `Sync-Log`  
EN: `memory`, `sync log`

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter privacyPolicyGerman_coversAppProcessingAndArt13 --filter privacyPolicyEnglish_coversAppProcessingAndArt13
```

Expected: FAIL missing needle.

- [ ] **Step 3: Write minimal implementation**

DE, im bestehenden Feedback-Absatz nach OS/Gerät ergänzen (kein neuer h3):

„zusätzlich Architektur, Arbeitsspeicher (physisch und Prozess), ggf. freier Volume-Platz, Thermalzustand, Energiesparmodus, iCloud an/aus sowie — sofern vorhanden — ein gekürzter, geschwärzter und zlib-komprimierter Auszug der lokalen Sync-Logs (Sync-Log).“

EN analog: `architecture, memory (physical and process), available disk if present, thermal state, low power mode, iCloud on/off, and if present a truncated, redacted, zlib-compressed excerpt of local sync logs`.

ASC-Tabelle: `Sonstige Diagnosedaten (OS, Gerät, Locale, Zeitzone, RAM/Disk/Thermal, Sync-Log-Auszug)`.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add docs/legal/privacy.html docs/legal/en/privacy.html \
  Tests/ReisenDomainTests/LegalPrivacyContentTests.swift \
  docs/ci/app-store-connect.md
git commit -m "$(cat <<'EOF'
docs: Diagnosedaten in Datenschutz und ASC an das Issue-Payload angleichen

Öffentliche Issues dürfen nicht mehr Felder senden, als die Erklärung nennt.
EOF
)"
```

---

## Spec-Abdeckung (Self-Review)

| Spec | Task |
| --- | --- |
| Umgebungstabelle | 1, 3 |
| nicht verfügbar vs. 0 | 1 |
| Log Tail/zlib/Preview/Lücken | 2 |
| Rotation | 2 |
| Kanäle API/URL/Kommentar/UI | 2, 3 |
| Fingerprint unverändert | 3 (bestehende Fingerprint-Tests nicht ändern) |
| Privacy/ASC | 4 |
| Live-Korpus open_gaps | kein Task (bewusst) |
| UI-Banner | kein Diff in SharedUI |
