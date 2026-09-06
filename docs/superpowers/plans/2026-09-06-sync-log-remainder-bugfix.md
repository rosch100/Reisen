# Sync-Log-Reste Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Nur Task 1–3 sind dieser /bugfix-Inner. Task 4+ sind fremde oder Folge-Sessions — nicht in diesem Worktree implementieren.

**Goal:** Check24-Hotel-Detail mit dauerhaftem `isLoading` beendet den Catalog-Sync nicht mehr; der Sync-Spinner endet nach Ankunft statt nach 32 s Timeout.

**Architecture:** Navigation-Ankunft bleibt SSOT in `ReisenProviders` (`NavigationSettleReady` / Confirm / Loop). Check24-Catalog isoliert Hotel-Enrich-Fehler. DOM-Bereitschaft bleibt `waitForHotelDetailReady`. Kein Check24-WebKit-Sonderweg.

**Tech Stack:** Swift, Swift Testing, WKWebView-Fassade `NavigationWebView`, `DiagnosticLogger`

## Global Constraints

- Kein Workaround statt Settle-Semantik (kein leeres catch, kein längeres Timeout als „Fix“)
- Kein Domain-WebKit; Check24 ruft weiter `NavigationAwaiter` / JS-Readiness
- Secrets/PII: URL-Rohwerte nur über Diagnostics-Redaction
- Tests: Swift Testing unter `Tests/`; bestehende Asserts nicht schwächen
- Parallel-Sessions nicht mergen/ändern: Opodo-Apple, Traveloka-Autofill, BMW-Session

## Parallel-Sessions (Audit 2026-09-06)

### Opodo / Apple — [c53e2e1f](c53e2e1f-7cd7-4e2a-9930-ca9767e5e418)

- Ledger: `.git/worktrees/bugfix-opodo-apple-login-twice/bugfix-state.md`
- Phase: P1, `root_cause_confirmed: false`, H1–H3 Judge **blocking**, H4 pending
- Richtig: GYG `AF8CC824` hat zwei Apple-Popups; Close-Pfad `webViewDidClose` → sofort `refreshParent` ist realer Code
- Falsch / Lücke: Opodo-Run `029A995C` hat **keine** Apple/Popup-Events — Opodo-Login ist kein Evidence für H4. Opodo-**Sync**-Timeout 61 s (`Zeitüberschreitung bei der Anforderung`, `fetchAuthenticatedText` Default 60 s) wird dort **nicht** behandelt
- Empfehlung: Session bei Apple-SSO lassen; nach Confirm nur Policy/Hosts. 60-s-GraphQL-Timeout = Folge-/bugfix (Task 5)

### Traveloka Autofill — [39926f30](39926f30-bc52-43d3-8d23-65c7851a2271)

- Ledger: `.git/worktrees/bugfix-traveloka-email-password-autofill/bugfix-state.md`
- Phase: P2, `root_cause_confirmed: true`, RED→GREEN gemessen (LoginAutofill 2-Step)
- Richtig: Log `filled succeeded` auf E-Mail-only-Stufe; Continue nicht als Submit; `filled = userFilled > 0`
- Lücke: Traveloka **HTTP 401** 08:29:26Z nach `session_ready` 08:24:14Z ist **nicht** Autofill — Catalog-`postJSON` / Sentinel vs. API-Auth
- Empfehlung: Autofill-Session unverändert lassen; 401 = Folge-/bugfix (Task 6)

### Billiger-Mietwagen Session — [64c98f2f](64c98f2f-0b37-48cd-8ebb-1b6c04267a0f)

- Ledger: `.git/worktrees/bugfix-bmw-session-not-recognized/bugfix-state.md`
- Phase: P2, `root_cause_confirmed: true`, Cookie-Change → `session.php` Re-Probe
- Richtig: eine `session_probe` `needs_login`, kein zweites Probe, kein `session_ready` — SPA ohne Document-Navigation
- Lücke: dreimal `fill_failed` ist Autofill-Feldsuche, nicht Session-Erkennung; nach manuellem Login reicht Cookie-Reprobe
- Empfehlung: Session-Fix dort belassen; `fill_failed` nur neu aufsetzen, wenn nach Reprobe die Ampel grün und Autofill trotzdem Pflicht ist

## Restprobleme (dieses /bugfix vs. Folge)

| ID | Symptom (Log) | Dieser Inner? |
| --- | --- | --- |
| C24-NAV | Hotel-Detail `is_loading=true` + `target=true` → Catalog-Fail, Spinner 32 s | ja (Task 1–3) |
| C24-POLL | `NavigationSettleLoop.poll` alle 100 ms publicDiagnostic | ja (Task 2) |
| OPO-SYNC | Opodo `durationMs=61110` ohne DiagnosticEvents | nein (Task 5) |
| TVL-401 | Traveloka HTTP 401 nach `session_ready` | nein (Task 6) |
| C24-AF | Check24 `session_ready` während Autofill, dann `fill_failed` (05.09. 18:44) | nein (Task 7) |
| LOG-ROT | `sync-log.txt` Zeile 1 mitten im JSON | nein (Task 8) |

---

### Task 1: Settle-Tests (RED)

**Files:**
- Create: `Tests/ReisenProvidersTests/NavigationSettleReadyTests.swift`
- Modify: `Tests/ReisenProvidersTests/NavigationAwaiterHotspotsTests.swift`
- Test: dieselben Dateien

**Interfaces:**
- Consumes: `NavigationSettleReady`, `NavigationSettleConfirm`, `NavigationAwaiter`, `FakeNavigationWebView`
- Produces: rote Tests für on-target-trotz-ignoring und Catalog-Isolation (Task 3)

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
import ReisenProviders

@MainActor
struct NavigationSettleReadyTests {
    @Test func onTargetStillLoading_isNotSettledImmediately() {
        let url = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
        let webView = FakeNavigationWebView(url: url, isLoading: true)
        #expect(
            NavigationSettleReady.isSettled(
                webView: webView,
                targetHost: "hotel.check24.de",
                targetPath: "/kundenbereich/buchung/abc",
                sawLoading: true
            ) == false
        )
    }

    @Test func onTargetStillLoading_afterGrace_isSettled() {
        let url = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
        let webView = FakeNavigationWebView(url: url, isLoading: true)
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(
            NavigationSettleReady.isSettled(
                webView: webView,
                targetHost: "hotel.check24.de",
                targetPath: "/kundenbereich/buchung/abc",
                sawLoading: true,
                onTargetSince: start,
                now: start.addingTimeInterval(2.0)
            )
        )
    }

    @Test func onTargetStillLoading_beforeGrace_isNotSettled() {
        let url = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
        let webView = FakeNavigationWebView(url: url, isLoading: true)
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(
            NavigationSettleReady.isSettled(
                webView: webView,
                targetHost: "hotel.check24.de",
                targetPath: "/kundenbereich/buchung/abc",
                sawLoading: true,
                onTargetSince: start,
                now: start.addingTimeInterval(0.5)
            ) == false
        )
    }
}
```

In `NavigationAwaiterHotspotsTests.swift` ergänzen:

```swift
@Test("NavigationAwaiter.load: on-target + isLoading endet nicht mit Timeout")
func navigationAwaiterSucceeds_whenOnTargetButStillLoading() async throws {
    let url = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
    let webView = FakeNavigationWebView(url: url, isLoading: true)
    let awaiter = NavigationAwaiter(timeoutSeconds: 4)
    try await awaiter.load(url, in: webView)
    #expect(webView.loadRequests.count == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter NavigationSettleReadyTests --filter navigationAwaiterSucceeds_whenOnTargetButStillLoading`

Expected: FAIL — Grace-`isSettled` fehlt; Awaiter wirft `NavigationAwaiter` code 1

---

### Task 2: Settle-Semantik + Poll-Log

**Files:**
- Modify: `Sources/ReisenProviders/NavigationSettleReady.swift`
- Modify: `Sources/ReisenProviders/NavigationSettleConfirm.swift`
- Modify: `Sources/ReisenProviders/NavigationSettleLoop.swift`
- Test: Task-1-Filter

**Interfaces:**
- Consumes: `NavigationTargetMatching.isOnTarget`
- Produces: `NavigationSettleReady.isSettled(...)`, Grace 2 s, Loop ohne `poll`/`settle_check`-Flood

- [ ] **Step 3: Implement settle accept**

`NavigationSettleReady.swift`:

```swift
import Foundation

@MainActor
public enum NavigationSettleReady {
    public static let onTargetLoadingGrace: TimeInterval = 2.0

    public static func isSettled(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: Bool,
        onTargetSince: Date? = nil,
        now: Date = Date()
    ) -> Bool {
        let onTarget = NavigationTargetMatching.isOnTarget(
            webView: webView,
            host: targetHost,
            path: targetPath
        )
        guard onTarget, sawLoading || webView.url != nil else { return false }
        if !webView.isLoading { return true }
        guard let since = onTargetSince else { return false }
        return now.timeIntervalSince(since) >= onTargetLoadingGrace
    }
}
```

`NavigationSettleConfirm.tryConfirm`: nach `Task.sleep(350ms)` dieselbe `isSettled`-Regel mit `onTargetSince`, nicht hart `!isLoading`.

`NavigationSettleLoop.wait`: `onTargetSince` setzen/löschen bei Target-Wechsel. Tick über `isSettled`. Bei Deadline: wenn `isOnTarget` → einmal `deadline_on_target` und `return`, sonst Timeout. Unbedingtes `event: "poll"` und Tick-`settle_check` entfernen; `url_changed` / `loading_changed` / `target_match_changed` behalten.

- [ ] **Step 4: Run Task-1 tests to verify they pass**

Run: `swift test --filter NavigationSettleReadyTests --filter navigationAwaiterSucceeds_whenOnTargetButStillLoading --filter navigationAwaiterTimeout_whenNotOnTarget --filter navigationAwaiterEarlyReturn`

Expected: PASS — Timeout-Test (nicht on-target) bleibt rot-grün wie bisher

---

### Task 3: Check24 Catalog isoliert Hotel-Enrich

**Files:**
- Modify: `Sources/ReisenCheck24/Sync/Check24TravelProvider+CatalogEnrich.swift`
- Create or Modify: bestehender Check24-Catalog-Test (suchen `enrichHotelBookings` / `Check24TravelProvider`); sonst `Tests/ReisenCheck24Tests/Check24HotelEnrichIsolationTests.swift` als reiner Helper-Test der Isolation-Funktion, falls der Provider nicht ohne WKWebView instanziierbar ist
- Test: Isolation-Unit

**Interfaces:**
- Consumes: `enrichHotelDetail` throws
- Produces: `fetchCatalog` liefert Activities-Drafts auch nach einem Hotel-Timeout

- [ ] **Step 5: Write isolation test**

Fachlicher Assert: eine Funktion `shouldAbortCatalog(afterHotelEnrichError:)` bzw. der Catch in `enrichHotelBookings` — `CancellationError` / `Task.isCancelled` → rethrow; `NSError` domain `NavigationAwaiter` → log + continue.

Wenn kein bestehender Test den Provider ohne Live-WebView treibt: extrahiere

```swift
enum Check24HotelEnrichIsolation {
    static func shouldRethrow(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if Task.isCancelled { return true }
        if NavigationSettleTimeout.isTimeout(error) { return false }
        return true
    }
}
```

Test:

```swift
@Test func hotelNavigationTimeout_doesNotAbortCatalog() {
    let timeout = NavigationSettleTimeout.error(
        for: URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
    )
    #expect(Check24HotelEnrichIsolation.shouldRethrow(timeout) == false)
}

@Test func hotelEnrichCancellation_abortsCatalog() {
    #expect(Check24HotelEnrichIsolation.shouldRethrow(CancellationError()) == true)
}
```

- [ ] **Step 6: Implement catch in enrichHotelBookings**

In der `for`-Schleife um `enrichHotelDetail`:

```swift
do {
    try await enrichHotelDetail(...)
} catch {
    guard !Check24HotelEnrichIsolation.shouldRethrow(error) else { throw error }
    await recordDiagnosticPhase(
        "hotel_detail",
        event: "enrich_failed",
        result: .failed,
        url: bookingURL,
        reason: NavigationSettleTimeout.diagnosticReason
    )
    continue
}
```

- [ ] **Step 7: Run isolation + settle tests**

Run: `swift test --filter NavigationSettleReadyTests --filter navigationAwaiter --filter hotelNavigationTimeout --filter hotelEnrichCancellation`

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add Sources/ReisenProviders/NavigationSettleReady.swift \
  Sources/ReisenProviders/NavigationSettleConfirm.swift \
  Sources/ReisenProviders/NavigationSettleLoop.swift \
  Sources/ReisenCheck24/Sync/Check24TravelProvider+CatalogEnrich.swift \
  Tests/ReisenProvidersTests/NavigationSettleReadyTests.swift \
  Tests/ReisenProvidersTests/NavigationAwaiterHotspotsTests.swift \
  Tests/ReisenCheck24Tests/Check24HotelEnrichIsolationTests.swift \
  docs/superpowers/specs/2026-09-06-check24-hotel-nav-timeout-design.md \
  docs/superpowers/plans/2026-09-06-sync-log-remainder-bugfix.md
git commit -m "$(cat <<'EOF'
fix: Check24-Hotel-Sync nicht an dauerhaftem WebView-Loading scheitern

Navigation gilt als angekommen, sobald die Ziel-URL matcht. Ein Hotel-Timeout
bricht den Catalog nicht mehr.
EOF
)"
```

---

### Task 4: Nicht implementieren — Opodo-Apple-Session

Fremde Session [c53e2e1f](c53e2e1f-7cd7-4e2a-9930-ca9767e5e418). Kein Diff in diesem Worktree. Nach P1-Confirm dort: ein Close-Pfad mit Delay für IdP-Close ohne Provider-Return. Opodo-Login-Telemetrie (`popup_*` auf Opodo) dort ergänzen, nicht hier.

### Task 5: Folge-/bugfix — Opodo GraphQL 60 s

Log: `result=failure provider=opodo durationMs=61110 error=Zeitüberschreitung bei der Anforderung.` Kein DiagnosticEvent. Ursache-Kandidat: `WKWebView.fetchAuthenticatedText` `timeoutSeconds: 60` ohne `DiagnosticLogger`. Eigenes /bugfix: Start/Erfolg/Timeout-Events + typisierter Timeout, nicht stilles URLSession-LocalizedString.

### Task 6: Folge-/bugfix — Traveloka Catalog 401

Log: `session_ready` 08:24:14Z, `result=failure` HTTP 401 08:29:26Z. `requireSessionContext` prüft `sen_t`; Catalog-POST kann trotzdem 401. Eigenes /bugfix nach Abschluss der Autofill-Session. Nicht mit Zweistufen-Fill vermischen.

### Task 7: Folge-/bugfix — Check24 Autofill-Race

Log 2026-09-05T18:44:58Z: `session_ready` auf `kundenbereich.check24.de` während `ProviderLoginAssistance` attempt 1–3, dann `fill_failed`. Eigenes /bugfix: Session-Heuristik vs. Login-Seite.

### Task 8: Folge-/bugfix — SyncLog-Rotation

`rotateIfNeeded` schreibt die letzten 65 KB roh — erste Logzeile ist mitten im JSON. Eigenes kleines /bugfix: Rotation an `\n`-Grenze.

## Self-Review

1. Spec-Punkte 1–5 → Task 1–3. Parallel-Audit → Einleitung + Task 4. Log-Reste → Task 5–8.
2. Keine TBD/TODO-Platzhalter in Task 1–3.
3. `isSettled` / `onTargetLoadingGrace` / `Check24HotelEnrichIsolation.shouldRethrow` sind in Tests und Implementierung gleich benannt.
