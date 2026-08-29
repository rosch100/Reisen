# App-Absturz als GitHub-Issue — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (tasks are tightly coupled around `GitHubIssueCrashCatcher`). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fatale POSIX-Signale (inkl. Swift-`SIGTRAP`) schreiben denselben Pending-Crash-Report wie unbehandelte `NSException` und werden beim nächsten Start über `GitHubIssueReporter` als öffentliches GitHub-Issue gesendet.

**Architecture:** C-Writer und `sigaction` in ReisenAppCore bleiben async-signal-safe. `prepare` speichert nur Pfad + Opt-in und öffnet/trunciert keine Datei. Write öffnet im Handler. Swift flushed unverändert. Opt-in-Refresh über `AppBootstrap` + `UserDefaults.didChangeNotification`, nicht über `SettingsView`.

**Tech Stack:** Swift 6.3 / Darwin `sigaction` / `backtrace` / Swift Testing.

## Global Constraints

- Schicht: nur `ReisenAppCore` GitHubIssues + `include/ReisenCrashSignal.h`; `AppBootstrap` ist der einzige Install- und Refresh-Ort.
- Opt-in Default aus; Versand nur wenn `GitHubIssueAutoReport.isAutomaticReportingEnabled()`.
- Issue: `kind/error`, `source/in-app`, Titel `GitHubIssueTitle.uncaughtException`.
- Kein Test löst `SIGTRAP`/`abort` im Testprozess aus.
- Handler löst das Signal danach erneut aus (App bleibt tot).
- `SecretRedactor` nicht im Signal-Handler; Flush redigiert gelesenen Text.
- Debugger (`P_TRACED`): keine Signal-Handler.
- Bestehende Pending-Datei (voriger Crash oder NSException) niemals truncaten oder überschreiben.
- Prepare legt bei Opt-out keine Datei an.
- UTF-8 ohne BOM; keine Secrets in Logs.

## File map

- Create: `Sources/ReisenAppCore/include/ReisenCrashSignal.h`
- Create: `Sources/ReisenAppCore/GitHubIssues/ReisenCrashSignal.c`
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueCrashCatcher.swift`
- Modify: `Sources/ReisenAppCore/AppBootstrap.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueAutoReportTests.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings` (Footer „inkl. Abstürze“)

---

### Task 1: Signal-safe Writer (kein Truncate, TDD fachlich)

**Files:**
- Create: `Sources/ReisenAppCore/include/ReisenCrashSignal.h`
- Create: `Sources/ReisenAppCore/GitHubIssues/ReisenCrashSignal.c`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueAutoReportTests.swift`

**Interfaces:**
- Consumes: POSIX `open`/`write`/`close`/`backtrace`/`fstat`
- Produces:
  - `bool reisen_crash_signal_prepare(const char *path, bool opted_in);` — kopiert Pfad, setzt Opt-in, **kein** Datei-I/O
  - `void reisen_crash_signal_set_opted_in(bool opted_in);`
  - `void reisen_crash_signal_mark_written(void);`
  - `void reisen_crash_signal_reset_for_tests(void);` — leert `path_buf`, setzt Flags auf 0; **kein** fd (Prepare hat keines)
  - `bool reisen_crash_signal_write_to_fd(int fd, int sig, const uintptr_t *frames, int frame_count);`
  - `bool reisen_crash_signal_write_current(int sig);` — öffnet aus path_buf wenn opted_in und Datei nicht existiert und !already_written
  - `bool reisen_crash_signal_install(bool debugger_attached);`

- [ ] **Step 1: Header + kompilierende Stubs (noch kein korrektes Verhalten)**

`Sources/ReisenAppCore/include/ReisenCrashSignal.h`:

```c
#pragma once

#include <stdbool.h>
#include <stdint.h>

enum { REISEN_CRASH_SIGNAL_MAX_FRAMES = 32 };

bool reisen_crash_signal_prepare(const char *path, bool opted_in);
void reisen_crash_signal_set_opted_in(bool opted_in);
void reisen_crash_signal_mark_written(void);
void reisen_crash_signal_reset_for_tests(void);
bool reisen_crash_signal_write_to_fd(int fd, int sig, const uintptr_t *frames, int frame_count);
bool reisen_crash_signal_write_current(int sig);
bool reisen_crash_signal_install(bool debugger_attached);
```

`Sources/ReisenAppCore/GitHubIssues/ReisenCrashSignal.c` zuerst nur Stubs: `write_to_fd` und `write_current` geben `false` zurück und schreiben nichts; `prepare` gibt `true` zurück ohne I/O; `install(true)` gibt `false` zurück, `install(false)` vorerst ebenfalls `false`; `reset_for_tests` leer.

Damit kompiliert das Modul. Noch kein GREEN der fachlichen Tests.

- [ ] **Step 2: Write failing behavioral tests**

In `Tests/ReisenAppCoreTests/GitHubIssueAutoReportTests.swift` `import Darwin` ergänzen und eine serialisierte Suite anlegen:

```swift
@Suite(.serialized)
struct GitHubIssueCrashSignalTests {
    init() {
        reisen_crash_signal_reset_for_tests()
    }

    @Test func writesNameAndHexAddressesToFd() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-fd-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let fd = open(url.path, O_CREAT | O_RDWR | O_TRUNC, S_IRUSR | S_IWUSR)
        #expect(fd >= 0)
        defer { if fd >= 0 { close(fd) } }
        var frames: [UInt] = [0xABC]
        let ok = frames.withUnsafeBufferPointer { buffer in
            reisen_crash_signal_write_to_fd(fd, SIGTRAP, buffer.baseAddress, Int32(buffer.count))
        }
        #expect(ok)
        fsync(fd)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("SIGTRAP"))
        #expect(text.lowercased().contains("abc"))
    }

    @Test func optedOutPrepareDoesNotCreateFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-optout-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, false))
        #expect(!reisen_crash_signal_write_current(SIGTRAP))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func setOptedInAfterPrepareAllowsWrite() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-refresh-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, false))
        reisen_crash_signal_set_opted_in(true)
        #expect(reisen_crash_signal_write_current(SIGTRAP))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("SIGTRAP"))
    }

    @Test func setOptedOutAfterPrepareDoesNotWrite() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-off-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, true))
        reisen_crash_signal_set_opted_in(false)
        #expect(!reisen_crash_signal_write_current(SIGTRAP))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func existingFileIsNotOverwritten() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-keep-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("NSException: kept\n".utf8).write(to: url)
        #expect(reisen_crash_signal_prepare(url.path, true))
        #expect(!reisen_crash_signal_write_current(SIGABRT))
        let stored = try String(contentsOf: url, encoding: .utf8)
        #expect(stored.contains("NSException: kept"))
        #expect(!stored.contains("SIGABRT"))
    }

    @Test func markWrittenBlocksSubsequentWrite() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-sig-mark-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(reisen_crash_signal_prepare(url.path, true))
        reisen_crash_signal_mark_written()
        #expect(!reisen_crash_signal_write_current(SIGABRT))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func installIsNoOpWhenDebuggerAttached() {
        #expect(!reisen_crash_signal_install(true))
    }
}
```

- [ ] **Step 3: Run tests — expect RED as assertion fail, not missing symbol**

```bash
cd /Users/roschmac/Entwicklung/Reisen/.worktrees/feat-uncaught-crash-report
swift test --filter GitHubIssueCrashSignalTests
```

Expected: Tests **laufen** und **scheitern** an `#expect(ok)` / `#expect(write_current)` / Dateiinhalt. Nicht an „cannot find `reisen_crash_signal_*`“.

- [ ] **Step 4: Implement real C behavior**

Statische State: `char path_buf[1024]`, `sig_atomic_t opted_in`, `sig_atomic_t already_written`. Kein dauerhaft offenes `pending_fd` aus Prepare.

`prepare`: `strlcpy` Pfad, `opted_in = …`, `already_written = 0`, return true wenn path nicht leer und `strlen < 1024`. **Kein open.**

`write_current`:
1. wenn `!opted_in` oder `already_written` oder `path_buf[0]==0` → false
2. `stat`/`access`: wenn Datei existiert → false (nicht überschreiben)
3. `open(path, O_CREAT|O_WRONLY|O_EXCL, 0600)` — wenn EEXIST → false
4. `backtrace` in statisches `void *frames[32]`
5. `write_to_fd(fd, sig, …)`
6. `already_written = 1`, `close(fd)`
7. return Ergebnis von `write_to_fd`

`write_to_fd`: Signalname (`SIGTRAP` etc., sonst `SIGNAL` + Dezimalzahl) + `\n` + je Frame `0x` + lowercase hex + `\n`. Kein malloc.

`install(debugger_attached)`: true → return false. false → `sigaction` für SIGTRAP, SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE; Handler ruft `write_current` auf, dann `signal(sig, SIG_DFL)` und `raise(sig)`; `SA_RESETHAND`; return true.

`reset_for_tests`: path leeren, flags 0, nichts an Prozess-Signalhandlern ändern.

- [ ] **Step 5: Run tests — GREEN**

```bash
swift test --filter GitHubIssueCrashSignalTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/ReisenAppCore/include/ReisenCrashSignal.h \
  Sources/ReisenAppCore/GitHubIssues/ReisenCrashSignal.c \
  Tests/ReisenAppCoreTests/GitHubIssueAutoReportTests.swift
git commit -m "$(cat <<'EOF'
feat: write pending crash reports for fatal POSIX signals

EOF
)"
```

---

### Task 2: Catcher, Bootstrap-Refresh, Flush-Redact

**Files:**
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueCrashCatcher.swift`
- Modify: `Sources/ReisenAppCore/AppBootstrap.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueAutoReportTests.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: Task-1-C-API; `GitHubIssueAutoReport.isAutomaticReportingEnabled()`; `PersistenceBootstrap.supportDirectoryURL()`
- Produces: `install()` bereitet Pfad vor ohne Truncate, installiert Signale außer Debugger; `refreshFatalSignalOptIn()`; `writePending` gibt Bool zurück und `mark_written` nur bei Erfolg; `pendingMessageForReport` redigiert; AppBootstrap beobachtet UserDefaults

- [ ] **Step 1: Failing test against the existing Catcher API (no new Swift names yet)**

`pendingMessageForReport` existiert bereits und gibt heute den Rohtext zurück. Truncate-Schutz ist in Task 1 (`existingFileIsNotOverwritten` + `prepare` ohne I/O) abgedeckt — hier keinen neuen Wrapper `prepareFatalSignalPending` im Test aufrufen, bevor er im Implement-Schritt existiert.

```swift
@Test func githubIssueCrashPending_redactsOnReadForFlush() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("reisen-crash-raw-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("SIGTRAP\n/Users/roschmac/Library/Reisen\n".utf8).write(to: url)
    let message = GitHubIssueCrashCatcher.pendingMessageForReport(at: url, optedIn: true)
    let stored = try #require(message)
    #expect(stored.contains("SIGTRAP"))
    #expect(!stored.contains("roschmac"))
}
```

- [ ] **Step 2: Run — RED auf Redact (aktuell gibt Read den Rohtext zurück)**

```bash
swift test --filter githubIssueCrashPending_redactsOnReadForFlush
```

Expected: FAIL Assert `roschmac` noch enthalten (nicht Compile-Fail). `prepareFatalSignalPending` kommt erst in Step 3 als interner Wrapper um `reisen_crash_signal_prepare`.

- [ ] **Step 3: Implement wiring**

`GitHubIssueCrashCatcher.install()`:

```swift
static func install() {
    previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()
    NSSetUncaughtExceptionHandler(reisenUncaughtExceptionHandler)
    if let url = pendingURL {
        prepareFatalSignalPending(
            at: url,
            optedIn: GitHubIssueAutoReport.isAutomaticReportingEnabled()
        )
    }
    _ = reisen_crash_signal_install(isDebuggerAttached())
}
```

`writePending` → `Bool` (false wenn !optedIn oder I/O-Fehler). `appendPending` ruft `reisen_crash_signal_mark_written()` nur bei `true`.

`pendingMessageForReport`: nach Lesen `SecretRedactor.redact(raw)`.

`isDebuggerAttached()` via `sysctl` + `P_TRACED` (`import Darwin`).

`AppBootstrap.init` nach `GitHubIssueCrashCatcher.install()`:

```swift
NotificationCenter.default.addObserver(
    forName: UserDefaults.didChangeNotification,
    object: UserDefaults.standard,
    queue: .main
) { _ in
    GitHubIssueCrashCatcher.refreshFatalSignalOptIn()
}
```

Observer-Token in einer Property halten, damit er nicht verschwindet. `refreshFatalSignalOptIn` ruft `reisen_crash_signal_set_opted_in(GitHubIssueAutoReport.isAutomaticReportingEnabled())`.

Keine Änderung an `SettingsView`.

Footer `settings.feedback_footer_embedded` DE: „Automatische Fehler-Issues (inkl. Abstürze) nur mit dem Schalter oben und sind öffentlich.“ EN analog „including crashes“.

- [ ] **Step 4: Tests + CI**

```bash
swift test --filter githubIssueCrash
bash ./Scripts/ci-test.sh
```

Expected: Exit 0.

- [ ] **Step 5: Commit**

Spec, Plan, Catcher, Bootstrap, Tests, xcstrings:

```bash
git add Sources/ReisenAppCore/GitHubIssues/GitHubIssueCrashCatcher.swift \
  Sources/ReisenAppCore/AppBootstrap.swift \
  Sources/ReisenDomain/Resources/Localizable.xcstrings \
  Tests/ReisenAppCoreTests/GitHubIssueAutoReportTests.swift \
  docs/superpowers/specs/2026-08-28-uncaught-crash-github-issue-design.md \
  docs/superpowers/plans/2026-08-28-uncaught-crash-github-issue.md
git commit -m "$(cat <<'EOF'
feat: report fatal Swift traps as GitHub issues on next launch

EOF
)"
```
