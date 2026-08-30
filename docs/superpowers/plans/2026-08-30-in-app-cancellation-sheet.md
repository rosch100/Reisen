# In-App-Cancellation-Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (tasks are coupled through Domain-Typen). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stornieren nur bei anzeigbarer Frist; gleiche Storno-URL wie Öffnen bleibt möglich; Tap öffnet die Hub-`WKWebView` im Sheet (Safari nur bei eigener Storno-Seite ohne Session).

**Architecture:** Domain bleibt WebKit-frei: `isActionable` + `BookingPortalCancelPresentation` mit `hasSessionWebView: Bool`. AppCore besitzt `ProviderWebViewDisplayOwner` am bestehenden `ProviderSessionHub`. SharedUI zeichnet den destruktiven Button und Sheet-Chrome. macOS/`ReiseniOS`-Hosts betten dieselbe Hub-Instanz ein und stehlen sie nicht, solange Owner `cancelSheet` ist.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, WKWebView (bestehende Hosts), L10n `Localizable.xcstrings`.

## Global Constraints

- Domain: kein WebKit, kein SwiftData, kein stiller Fallback (`?? externalUrl`).
- Kein zweites WKWebView, keine Cancel-API, kein lokales `cancelled`, kein Settings-Toggle, kein `confirmationDialog`, kein XCUI.
- DE-Button-Titel genau „Stornieren“; Key `action.cancel_in_portal`; Sheet-Dismiss `common.cancel`.
- Storno-URL unverändert laden (kein UUID in den Pfad); Fragment behalten.
- Sheet-`load`-Fehler: Banner im Sheet, kein Safari.
- Schicht-Landung laut Spec: Domain → AppCore → SharedUI → Apps.
- Tests: `swift test --filter <Name>`; CI-Parität später `bash ./Scripts/ci-test.sh`.
- Bestehende Assertions nicht schwächen — `same`-URL-Fall in `BookingPortalCancellationTests` **umdrehen** (jetzt actionable, Sichtbarkeit über Presentation).

---

## File map

| Datei | Rolle |
|-------|--------|
| `Sources/ReisenDomain/Services/BookingPortalCancellation.swift` | `isActionable`, `presentation`, `visible` |
| `Tests/ReisenDomainTests/BookingPortalCancellationTests.swift` | Contract + Presentation + Hash |
| `Sources/ReisenDomain/Entities/BookingPortalCancelTitle.swift` | unverändert (liest L10n) |
| `Sources/ReisenDomain/Resources/Localizable.xcstrings` | DE „Stornieren“ + Load-Fehler |
| `Sources/ReisenDomain/Localization/L10nKey.swift` | `bookingPortalCancelLoadFailed` |
| `Tests/ReisenDomainTests/BookingPortalCancelTitleTests.swift` | DE-String-Assert |
| `Sources/ReisenAppCore/ProviderWebViewDisplayPolicy.swift` | Owner × Host → `allowsEmbed` |
| `Sources/ReisenAppCore/ProviderSessionHub.swift` | `webViewDisplayOwner` |
| `Tests/ReisenAppCoreTests/ProviderWebViewDisplayPolicyTests.swift` | Policy + Owner-Reset |
| `Sources/ReisenSharedUI/BookingPortalOpenLink.swift` | destruktiver Button, Callback statt `Link` für Cancel |
| `Sources/ReisenSharedUI/BookingPortalCancelSheetChrome.swift` | Sheet-Chrome (Dismiss + Fehler) |
| `Sources/Reisen/Platform/ProviderSessionView.swift` | `allowsEmbed` (kein Default) |
| `Sources/Reisen/App/SyncView.swift` | bestehendes Hub-Binding; `allowsEmbed(on: .sync)` |
| `Sources/Reisen/App/ProviderSessionProbeHost.swift` | Hub-Binding; `allowsEmbed(on: .probe)` |
| `Sources/Reisen/App/ProviderSyncContainer.swift` | Probe-Host `allowsEmbed(on: .probe)` |
| `Sources/Reisen/App/BookingPortalCancelSheetHost.swift` | macOS-Sheet, load, Owner |
| `Sources/Reisen/App/BookingPortalOpenCommandState.swift` | Fristen + `hasSessionWebView` + Present |
| `Sources/Reisen/App/ReisenCommands.swift` | Command ruft Presentation, nicht blind `openURL` |
| `Sources/Reisen/App/ContentView.swift` | Sheet-State, Command-State |
| `Sources/Reisen/App/BookingDetailContent.swift` | ActionBar: Pflichtparameter `deadlines`, `hasSessionWebView`, `onPresentCancel` (kein Default) |
| `Apps/ReiseniOS/ProviderSync/WebViewHost.swift` | `resolveWebView` + `allowsEmbed` in `makeUIView` **und** `updateUIView` (Hub-Instanz, kein zweites WKWebView) |
| `Apps/ReiseniOS/ProviderSync/SyncTab.swift` | Sync-Host `allowsEmbed(on: .sync)` |
| `Apps/ReiseniOS/ProviderSync/GlobalChrome.swift` | Probe-Host `allowsEmbed(on: .probe)` |
| `Apps/ReiseniOS/Shared/BookingDetailIOS.swift` | ActionBar + Sheet |
| `Apps/ReiseniOS/Shared/OffenTab.swift` | Kontextmenü-Storno |
| `Apps/ReiseniOS/Shared/TripDetailIOS.swift` | Kontextmenü-Storno |
| `Apps/ReiseniOS/Shared/BookingPortalCancelSheetHostIOS.swift` | iOS-Sheet, dieselbe Hub-Instanz |

---

### Task 1: Domain `isActionable` + Presentation

**Files:**
- Modify: `Sources/ReisenDomain/Services/BookingPortalCancellation.swift`
- Modify: `Tests/ReisenDomainTests/BookingPortalCancellationTests.swift`

**Interfaces:**
- Consumes: `CancellationDeadlineDisplayFilter.deadlinesForDisplay`, `BookingStatus`, `BookingExternalURL.browserURL`
- Produces: `BookingPortalCancellation.isActionable(cancellation:open:status:deadlines:now:) -> Bool`; `BookingPortalCancelPresentation`; `BookingPortalCancellation.presentation(...)`; `BookingPortalActions.visible(open:cancellation:status:deadlines:now:hasSessionWebView:)`

- [ ] **Step 1: Write the failing tests**

Replace `Tests/ReisenDomainTests/BookingPortalCancellationTests.swift` so the old `same → cancel == nil` case fails against the new contract, and add deadline/presentation/hash cases. Keep the existing `browserURL`-Filter-Test.

```swift
import Foundation
import Testing
import ReisenDomain

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let open = URL(string: "https://example.com/open")!
private let cancel = URL(string: "https://example.com/cancel")!

private func freeDeadline(days: Int = 2) -> CancellationDeadline {
    CancellationDeadline(
        deadlineAt: now.addingTimeInterval(TimeInterval(days * 86_400)),
        isFreeCancellation: true
    )
}

private func paid(amount: Double?, days: Int = 3) -> CancellationDeadline {
    CancellationDeadline(
        deadlineAt: now.addingTimeInterval(TimeInterval(days * 86_400)),
        isFreeCancellation: false,
        cancellationFeeAmount: amount
    )
}

@Test func bookingCancellationBrowserURL_usesSameFilterAsOpen() {
    var booking = Booking(
        provider: .traveloka,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2)
    )
    booking.cancellationUrl = "https://www.traveloka.com/en-en/refund/presubmission/HOTEL/a/b"
    #expect(booking.cancellationBrowserURL?.absoluteString == booking.cancellationUrl)

    booking.cancellationUrl = BookingExternalURL.makeManual()
    #expect(booking.cancellationBrowserURL == nil)
    booking.cancellationUrl = "   "
    #expect(booking.cancellationBrowserURL == nil)
}

@Test func bookingCancellationBrowserURL_keepsOpodoHashFragment() {
    var booking = Booking(
        provider: .opodo,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2)
    )
    let raw = "https://www.opodo.de/travel/secure/#tripdetails/td=token&funnel=cancellationHSA"
    booking.cancellationUrl = raw
    #expect(booking.cancellationBrowserURL?.absoluteString == raw)
    #expect(booking.cancellationBrowserURL?.fragment?.contains("funnel=cancellationHSA") == true)
}

@Test func bookingPortalCancellation_isActionable_requiresDisplayableDeadline() {
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [freeDeadline()], now: now
        )
    )
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: open, open: open, status: .confirmed,
            deadlines: [freeDeadline()], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .cancelled,
            deadlines: [freeDeadline()], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: nil, open: open, status: .confirmed,
            deadlines: [freeDeadline()], now: now
        )
    )
}

@Test func bookingPortalCancellation_isActionable_deadlineVariants() {
    let expired = CancellationDeadline(
        deadlineAt: now.addingTimeInterval(-86_400),
        isFreeCancellation: true
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [expired], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [paid(amount: 100)], now: now
        )
    )
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [paid(amount: 50), paid(amount: 100)], now: now
        )
    )
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [freeDeadline(), paid(amount: 100)], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [paid(amount: nil)], now: now
        )
    )
}

@Test func bookingPortalCancellation_presentation_routesSheetSafariHidden() {
    let deadlines = [freeDeadline()]
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: open, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: true
        ) == .sheet
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: open, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: false
        ) == .hidden
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: false
        ) == .safari
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: true
        ) == .sheet
    )
}

@Test func bookingPortalActions_visible_usesPresentation() {
    let deadlines = [freeDeadline()]
    let both = BookingPortalActions.visible(
        open: open, cancellation: cancel, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: true
    )
    #expect(both.open == open && both.cancel == cancel)

    let sameNoHub = BookingPortalActions.visible(
        open: open, cancellation: open, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: false
    )
    #expect(sameNoHub.open == open && sameNoHub.cancel == nil)

    let sameHub = BookingPortalActions.visible(
        open: open, cancellation: open, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: true
    )
    #expect(sameHub.open == open && sameHub.cancel == open)

    let onlyCancel = BookingPortalActions.visible(
        open: nil, cancellation: cancel, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: false
    )
    #expect(onlyCancel.open == nil && onlyCancel.cancel == cancel)

    let cancelled = BookingPortalActions.visible(
        open: open, cancellation: cancel, status: .cancelled,
        deadlines: deadlines, now: now, hasSessionWebView: true
    )
    #expect(cancelled.open == open && cancelled.cancel == nil)
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter bookingPortalCancellation`

Expected: FAIL — `isActionable` hat die neuen Parameter nicht / `same` ist noch `cancel == nil` / `presentation` fehlt.

- [ ] **Step 3: Implement Domain**

Replace `Sources/ReisenDomain/Services/BookingPortalCancellation.swift`:

```swift
import Foundation

public enum BookingPortalCancelPresentation: Equatable, Sendable {
    case sheet
    case safari
    case hidden
}

public enum BookingPortalCancellation {
    public static func isActionable(
        cancellation: URL?,
        open _: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date
    ) -> Bool {
        guard status != .cancelled, cancellation != nil else { return false }
        return !CancellationDeadlineDisplayFilter.deadlinesForDisplay(deadlines, now: now).isEmpty
    }

    public static func presentation(
        cancellation: URL?,
        open: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date,
        hasSessionWebView: Bool
    ) -> BookingPortalCancelPresentation {
        guard isActionable(
            cancellation: cancellation,
            open: open,
            status: status,
            deadlines: deadlines,
            now: now
        ) else { return .hidden }
        if hasSessionWebView { return .sheet }
        if cancellation != open { return .safari }
        return .hidden
    }
}

public enum BookingPortalActions {
    public struct Visible: Equatable, Sendable {
        public var open: URL?
        public var cancel: URL?
    }

    public static func visible(
        open: URL?,
        cancellation: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date,
        hasSessionWebView: Bool
    ) -> Visible {
        let shown: URL?
        switch BookingPortalCancellation.presentation(
            cancellation: cancellation,
            open: open,
            status: status,
            deadlines: deadlines,
            now: now,
            hasSessionWebView: hasSessionWebView
        ) {
        case .sheet, .safari:
            shown = cancellation
        case .hidden:
            shown = nil
        }
        return Visible(open: open, cancel: shown)
    }
}
```

Alle Call-Sites der alten Signatur kompilieren nicht — **keine** Default-Parameter für `hasSessionWebView` oder `deadlines`. Jede Site muss die Werte **explizit** übergeben.

Pflicht-Call-Sites (vollständig, Worktree-Stand):

| Datei | In diesem Task |
|-------|----------------|
| `BookingPortalOpenLink.swift` (`isVisible`, ActionBar, `CancelMenuItems`) | neue Parameter **ohne** Default |
| `BookingPortalOpenCommandState.swift` | `deadlines` + `hasSessionWebView` + `canCancel` über `presentation` |
| `BookingDetailContent.swift` | `deadlines: booking.resolvedCancellationDeadlines`; `hasSessionWebView` als **Init-Parameter vom Parent** (ContentView/TripDetail — Parent darf Task-1 `false` **explizit** übergeben) |
| `BookingDetailIOS.swift` | echte `deadlines`; `hasSessionWebView: false` explizit |
| `ContentView.swift` (2× MenuItems + Command-State) | echte `deadlines` der selektierten Buchung; `hasSessionWebView: false` explizit; leerer Command-State: `deadlines: []`, `hasSessionWebView: false` |
| `TripDetailView.swift` | echte `deadlines`; `hasSessionWebView: false` explizit |
| `OffenTab.swift` | echte `deadlines`; `hasSessionWebView: false` explizit |
| `TripDetailIOS.swift` | echte `deadlines`; `hasSessionWebView: false` explizit |

`false` ist die Task-1-Brücke (keine Session-Verdrahtung). Task 4 **ersetzt** jedes explizite `false` an Buchungs-Einstiegen durch `hub?.webView(for: booking.provider) != nil`. Kein `?? true`. `now: Date()` darf Default bleiben (injizierbar in Tests).

- [ ] **Step 4: GREEN**

Run: `swift test --filter bookingPortalCancellation`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/Services/BookingPortalCancellation.swift \
  Tests/ReisenDomainTests/BookingPortalCancellationTests.swift \
  Sources/ReisenSharedUI/BookingPortalOpenLink.swift \
  Sources/Reisen/App/BookingPortalOpenCommandState.swift \
  Sources/Reisen/App/BookingDetailContent.swift \
  Apps/ReiseniOS/Shared/BookingDetailIOS.swift \
  Sources/Reisen/App/ContentView.swift \
  Sources/Reisen/App/TripDetailView.swift \
  Sources/Reisen/App/ReisenCommands.swift \
  Apps/ReiseniOS/Shared/OffenTab.swift \
  Apps/ReiseniOS/Shared/TripDetailIOS.swift
git commit -m "$(cat <<'EOF'
feat: gate portal cancel on displayable deadlines

Stornieren bleibt bei gleicher URL wie Öffnen möglich; ohne anzeigbare Frist gibt es kein Control.
EOF
)"
```

Nur Dateien committen, die dieser Task wirklich geändert hat (Call-Site-Signaturen). Keine Sheet-UI in diesem Commit.

---

### Task 2: L10n „Stornieren“ + Load-Fehler

**Files:**
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings` (`action.cancel_in_portal` DE `Storno` → `Stornieren`)
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift` (neuer Key)
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings` (neuer Key)
- Modify: `Tests/ReisenDomainTests/BookingPortalCancelTitleTests.swift`

**Interfaces:**
- Consumes: `L10n.string`, `BookingPortalCancelTitle.button`
- Produces: DE-Button „Stornieren“; `L10nKey.bookingPortalCancelLoadFailed`

- [ ] **Step 1: Failing title test**

In `BookingPortalCancelTitleTests.swift` ergänzen:

```swift
@Test func bookingPortalCancelTitle_buttonIsStornierenInGerman() {
    L10n.withLocale(Locale(identifier: "de")) {
        #expect(BookingPortalCancelTitle.button == "Stornieren")
    }
}
```

- [ ] **Step 2: RED**

Run: `swift test --filter bookingPortalCancelTitle_buttonIsStornierenInGerman`

Expected: FAIL (`Storno` != `Stornieren`). `bookingPortalCancelLoadFailed` existiert noch nicht — den Resolve-Test erst nach Step 3 anlegen, sonst kompiliert das Target nicht.

- [ ] **Step 3: Strings**

In `Localizable.xcstrings` bei Key `action.cancel_in_portal` das DE-`value` von `Storno` auf `Stornieren` ändern. EN unverändert `Cancel in portal`.

In `L10nKey.swift` alphabetisch nahe `bookingDetail*`:

```swift
case bookingPortalCancelLoadFailed = "booking.portal_cancel_load_failed"
```

In `Localizable.xcstrings` neuen Eintrag:

- DE: `Die Stornoseite konnte nicht geladen werden.`
- EN: `The cancellation page could not be loaded.`

Help-Text (`action.cancel_in_portal_help`) bleibt: Öffnen der Stornoseite, kein Storno in Reisen. Menu-Key bleibt „Stornieren im Portal“.

```swift
@Test func bookingPortalCancelLoadFailed_keyResolves() {
    L10n.withLocale(Locale(identifier: "de")) {
        let value = L10n.string(.bookingPortalCancelLoadFailed)
        #expect(value != L10nKey.bookingPortalCancelLoadFailed.rawValue)
        #expect(!value.isEmpty)
    }
}
```

- [ ] **Step 4: GREEN**

Run: `swift test --filter bookingPortalCancelTitle`

Expected: PASS, inkl. bestehender Key-Resolve-Tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/Resources/Localizable.xcstrings \
  Sources/ReisenDomain/Localization/L10nKey.swift \
  Tests/ReisenDomainTests/BookingPortalCancelTitleTests.swift
git commit -m "$(cat <<'EOF'
feat: rename cancel control to Stornieren

Der Button heißt zerstörerisch Stornieren; der Load-Fehler im Sheet hat einen eigenen L10n-Key.
EOF
)"
```

---

### Task 3: Display-Owner am Hub

**Files:**
- Create: `Sources/ReisenAppCore/ProviderWebViewDisplayPolicy.swift`
- Modify: `Sources/ReisenAppCore/ProviderSessionHub.swift`
- Create: `Tests/ReisenAppCoreTests/ProviderWebViewDisplayPolicyTests.swift`

**Interfaces:**
- Consumes: bestehender `ProviderSessionHub`
- Produces: `ProviderWebViewDisplayOwner`, `ProviderWebViewHostRole`, `ProviderWebViewDisplayPolicy.allowsEmbed`, `ProviderSessionHub.webViewDisplayOwner` / `setWebViewDisplayOwner`

- [ ] **Step 1: Failing tests**

```swift
import Testing
@testable import ReisenAppCore

@Test func providerWebViewDisplayPolicy_syncHostAllowsProbeAndSyncOnly() {
    #expect(ProviderWebViewDisplayPolicy.allowsEmbed(owner: .syncHost, host: .probe))
    #expect(ProviderWebViewDisplayPolicy.allowsEmbed(owner: .syncHost, host: .sync))
    #expect(!ProviderWebViewDisplayPolicy.allowsEmbed(owner: .syncHost, host: .cancelSheet))
}

@Test func providerWebViewDisplayPolicy_cancelSheetAllowsSheetOnly() {
    #expect(!ProviderWebViewDisplayPolicy.allowsEmbed(owner: .cancelSheet, host: .probe))
    #expect(!ProviderWebViewDisplayPolicy.allowsEmbed(owner: .cancelSheet, host: .sync))
    #expect(ProviderWebViewDisplayPolicy.allowsEmbed(owner: .cancelSheet, host: .cancelSheet))
}

@Test @MainActor func providerSessionHub_displayOwnerDefaultsToSyncHostAndResets() {
    let hub = ProviderSessionHub()
    #expect(hub.webViewDisplayOwner == .syncHost)
    hub.setWebViewDisplayOwner(.cancelSheet)
    #expect(hub.webViewDisplayOwner == .cancelSheet)
    hub.setWebViewDisplayOwner(.syncHost)
    #expect(hub.webViewDisplayOwner == .syncHost)
}
```

- [ ] **Step 2: RED**

Run: `swift test --filter providerWebViewDisplayPolicy`

Expected: FAIL — Typen fehlen.

- [ ] **Step 3: Implement**

`Sources/ReisenAppCore/ProviderWebViewDisplayPolicy.swift`:

```swift
public enum ProviderWebViewDisplayOwner: Equatable, Sendable {
    case syncHost
    case cancelSheet
}

public enum ProviderWebViewHostRole: Equatable, Sendable {
    case probe
    case sync
    case cancelSheet
}

public enum ProviderWebViewDisplayPolicy {
    public static func allowsEmbed(
        owner: ProviderWebViewDisplayOwner,
        host: ProviderWebViewHostRole
    ) -> Bool {
        switch owner {
        case .syncHost:
            return host == .probe || host == .sync
        case .cancelSheet:
            return host == .cancelSheet
        }
    }
}
```

In `ProviderSessionHub` ergänzen:

```swift
public private(set) var webViewDisplayOwner: ProviderWebViewDisplayOwner = .syncHost

public func setWebViewDisplayOwner(_ owner: ProviderWebViewDisplayOwner) {
    webViewDisplayOwner = owner
}

public func allowsEmbed(on host: ProviderWebViewHostRole) -> Bool {
    ProviderWebViewDisplayPolicy.allowsEmbed(owner: webViewDisplayOwner, host: host)
}
```

Noch **keine** Host-Verdrahtung in diesem Task (sonst vermischt mit Sheet). Die Policy ist allein testbar.

- [ ] **Step 4: GREEN**

Run: `swift test --filter ProviderWebViewDisplay`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/ProviderWebViewDisplayPolicy.swift \
  Sources/ReisenAppCore/ProviderSessionHub.swift \
  Tests/ReisenAppCoreTests/ProviderWebViewDisplayPolicyTests.swift
git commit -m "$(cat <<'EOF'
feat: add webview display owner for cancel sheet

Probe- and Sync-Hosts must not reclaim the hub WebView while the cancel sheet owns it.
EOF
)"
```

---

### Task 4: Entry — destruktiver Button, Sheet, Hosts

**Files:**
- Modify: `Sources/ReisenSharedUI/BookingPortalOpenLink.swift` (ActionBar **und** `BookingPortalCancelMenuButton` / `MenuItems` — intern kein `openURL` bei `.sheet`)
- Create: `Sources/ReisenSharedUI/BookingPortalCancelSheetChrome.swift`
- Create: `Sources/Reisen/App/BookingPortalCancelSheetHost.swift`
- Create: `Apps/ReiseniOS/Shared/BookingPortalCancelSheetHostIOS.swift`
- Modify: macOS `ProviderSessionView` (`allowsEmbed` in `updateNSView`)
- Modify: iOS `WebViewHost.swift`: `resolveWebView` (Binding, sonst Hub, sonst neu); `embed` in `makeUIView` und `updateUIView`; Steal nur bei `allowsEmbed`
- Modify: `SyncTab.swift` — Binding wie macOS `SyncView.webViewBinding` (`get: state ?? hub.webView(for:)`, `set: state + hub.updateWebView`); `allowsEmbed(on: .sync)`
- Modify: `GlobalChrome.swift` `SyncBackgroundSessionProbe` — lokales `webViewsByProvider` **ersetzen** durch Hub-get/set (`hub.webView(for:)` / `updateWebView`); `allowsEmbed(on: .probe)`
- Modify: `SyncView.swift`, `ProviderSessionProbeHost.swift`, `ProviderSyncContainer.swift` — `allowsEmbed` ohne Default, Parent reicht `hub.allowsEmbed(on:)` bzw. `false` wenn kein Hub
- Modify: alle Einstiege inkl. `OffenTab.swift`, `TripDetailIOS.swift` — `hasSessionWebView` vom Hub, kein Default
- Test: `Tests/ReisenSharedUITests/BookingPortalCancelChromeTests.swift`

**Interfaces:**
- Consumes: `BookingPortalActions.visible`, `BookingPortalCancelPresentation`, `hub.allowsEmbed(on:)`, `hub.webView(for:)`, `L10n.string(.bookingPortalCancelLoadFailed)`, `common.cancel`
- Produces: sichtbarer Stornieren-Weg; Sheet lädt Storno-URL; Safari nur bei `.safari`

- [ ] **Step 1: SharedUI-Test (sichtbarer Weg, kein XCUI)**

```swift
import Testing
import ReisenDomain
@testable import ReisenSharedUI

@Test func bookingPortalCancelChrome_destructiveUsesStornierenTitle() {
    L10n.withLocale(Locale(identifier: "de")) {
        #expect(BookingPortalCancelTitle.button == "Stornieren")
        #expect(BookingPortalCancelChrome.systemImage == "arrow.up.right.square")
        #expect(BookingPortalCancelChrome.usesDestructiveRole)
    }
}

@Test func bookingPortalActionBar_isVisible_sameURLRequiresSession() {
    let url = URL(string: "https://example.com/booking")!
    let free = CancellationDeadline(
        deadlineAt: Date().addingTimeInterval(86_400),
        isFreeCancellation: true
    )
    #expect(
        !BookingPortalActionBar.isVisible(
            open: url, cancellation: url, status: .confirmed,
            deadlines: [free], now: Date(), hasSessionWebView: false
        )
    )
    #expect(
        BookingPortalActionBar.isVisible(
            open: url, cancellation: url, status: .confirmed,
            deadlines: [free], now: Date(), hasSessionWebView: true
        )
    )
}
```

`BookingPortalCancelChrome` ist die SSOT für Symbol + destructive-Flag (ActionBar und Menu lesen sie).

- [ ] **Step 2: RED**

Run: `swift test --filter bookingPortalCancelChrome`

Expected: FAIL — `BookingPortalCancelChrome` fehlt.

- [ ] **Step 3: SharedUI + Sheet-Hosts**

`BookingPortalCancelChrome`:

```swift
import SwiftUI
import ReisenDomain

public enum BookingPortalCancelChrome {
    public static let systemImage = "arrow.up.right.square"
    public static let usesDestructiveRole = true
}

public struct BookingPortalCancelSheetChrome<WebContent: View>: View {
    let loadFailed: Bool
    let onDismiss: () -> Void
    @ViewBuilder var webContent: () -> WebContent

    public init(
        loadFailed: Bool,
        onDismiss: @escaping () -> Void,
        @ViewBuilder webContent: @escaping () -> WebContent
    ) {
        self.loadFailed = loadFailed
        self.onDismiss = onDismiss
        self.webContent = webContent
    }

    public var body: some View {
        VStack(spacing: 0) {
            if loadFailed {
                Text(L10n.string(.bookingPortalCancelLoadFailed))
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(8)
            }
            webContent()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string(.commonCancel), action: onDismiss)
            }
        }
    }
}
```

ActionBar-Cancel-Zweig **und** `BookingPortalCancelMenuButton`: **kein** `Link`, **kein** internes `openURL`. `Button(role: .destructive)` mit `BookingPortalCancelTitle.button` / Menu-Titel + `BookingPortalCancelChrome.systemImage`. Action immer `onPresentCancel(presentation, url)`.

Neue Parameter an `BookingPortalActionBar` / `BookingPortalCancelMenuItems` / `BookingPortalCancelMenuButton` — **ohne** Default für `hasSessionWebView`, `deadlines`, `onPresentCancel`:

```swift
var deadlines: [CancellationDeadline]
var now: Date = Date()
var hasSessionWebView: Bool
var onPresentCancel: (BookingPortalCancelPresentation, URL) -> Void
```

`isVisible` delegiert an `BookingPortalActions.visible(...)`.

`BookingDetailContent` bekommt dieselben drei als Init-Parameter (kein Hub in SharedUI/Detail-Content). Parent (ContentView / Trip-Inspector) setzt `hasSessionWebView: hub?.webView(for: booking.provider) != nil`.

macOS `ProviderSessionView` / `ProviderWebView`: Parameter `allowsEmbed: Bool` **ohne** Default. In `updateNSView`:

```swift
guard allowsEmbed else { return }
```

Kein Embed/Steal wenn `false`. `makeNSView` bei `false`: leeren Host ohne `embed`.

iOS `ProviderSessionWebView` — **nicht** nur `allowsEmbed` auf `updateUIView` kleben. Pflicht analog macOS `resolveWebView`:

`WebViewHost` / `ProviderSessionWebView` brauchen die `ProviderID` (ist schon da) und `@Environment(\.providerSessionHub)` **oder** der Parent reicht die Hub-Instanz im Binding. `resolveWebView`:

```swift
private func resolveWebView(context: Context) -> InteractiveWKWebView {
    if let existing = webView as? InteractiveWKWebView {
        return existing
    }
    if let hubView = sessionHub?.webView(for: providerID) as? InteractiveWKWebView {
        return hubView
    }
    return makeWebView(context: context)
}
```

Erst Binding, dann Hub, erst dann `makeWebView`. Ohne Hub-Binding in `SyncTab`/`SyncBackgroundSessionProbe` erzeugt `makeUIView` weiter eine zweite Instanz.

`SyncTab` Binding (macOS-`SyncView` kopieren):

```swift
private var selectedSessionWebView: WKWebView? {
    sessionHub?.webView(for: selectedProviderID)
}

private var webViewBinding: Binding<WKWebView?> {
    Binding(
        get: { selectedSessionWebView },
        set: { newValue in
            webView = newValue
            sessionHub?.updateWebView(selectedProviderID, webView: newValue)
        }
    )
}
```

`SyncBackgroundSessionProbe.webViewBinding(for:)` — `webViewsByProvider` entfernen:

```swift
private func webViewBinding(for providerID: ProviderID) -> Binding<WKWebView?> {
    Binding(
        get: { sessionHub?.webView(for: providerID) },
        set: { sessionHub?.updateWebView(providerID, webView: $0) }
    )
}
```

```swift
func makeUIView(...) -> WebViewHostUIView {
    let host = WebViewHostUIView()
    let view = resolveWebView(context: context)
    if allowsEmbed { host.embed(view) }
    ...
}

func updateUIView(_ uiView: WebViewHostUIView, context: Context) {
    let view = resolveWebView(context: context)
    if allowsEmbed {
        if uiView.webView !== view || view.superview !== uiView {
            uiView.embed(view)
        }
    }
    // !allowsEmbed: nicht stehlen
    ...
}
```

Parents (kein `?? true`):

```swift
allowsEmbed: hub?.allowsEmbed(on: .sync) ?? false
```

`SyncTab`: `.sync`. `GlobalChrome`: `.probe`.

Nach Dismiss (`syncHost`): Sync-Host `updateUIView` bettet die **dieselbe** Instanz zurück.

macOS-Sheet-Host (`BookingPortalCancelSheetHost`):

1. `onAppear`: `hub.setWebViewDisplayOwner(.cancelSheet)`; `webView.load(URLRequest(url: cancellationURL))` — `cancellationURL` ist bereits `URL` (Fragment bleibt).
2. Navigation-Delegate-Fail → `loadFailed = true`. Nicht `openURL`. Vor dem Setzen den bestehenden Session-Delegate merken (`WebViewNavigationDelegateHandoff.take`); beim Dismantle nur restore, wenn der Cancel-Coordinator noch Owner ist — nicht pauschal `nil`.
3. `onDisappear` / Dismiss: `hub.setWebViewDisplayOwner(.syncHost)`. **Kein** Zurück-`load` der vorherigen URL.
4. Body: `BookingPortalCancelSheetChrome` + Einbettung der Hub-WebView (bestehende `ProviderSessionView` **nicht** mit `loginURL` verwenden). Eigener schmaler Host, der nur embed+load kann — z. B. dieselbe `WebViewHostView.embed`-Logik mit `allowsEmbed: hub.allowsEmbed(on: .cancelSheet)`.

iOS analog (`BookingPortalCancelSheetHostIOS`).

ContentView / BookingDetail / iOS Detail:

```swift
@State private var cancelRequest: BookingPortalCancelRequest?

onPresentCancel: { presentation, url in
    BookingPortalCancelRequest.handle(
        presentation,
        url: url,
        providerID: booking.provider,
        openURL: { openURL($0) },
        presentSheet: { cancelRequest = $0 }
    )
}
```

`.bookingPortalCancelSheet($cancelRequest)` (`sheet(item:)`). Toolbar und interaktives Dismiss setzen das Item auf `nil`; `onDisappear` gibt den Display-Owner zurück.

`hasSessionWebView` an **jedem** Buchungs-Einstieg: `hub?.webView(for: booking.provider) != nil` (explizit, kein Default). Store-iOS / fehlender Hub → `false`. Pflicht-Sites: `BookingDetailContent`-Parent, `BookingDetailIOS`, `ContentView` (Menu + Command), `TripDetailView`, `OffenTab`, `TripDetailIOS`.

Command-State: `canCancel` über `presentation != .hidden`. Button in `ReisenCommands` ruft `onPresentCancel` (Closure im FocusedValue) oder postet `Notification.Name.reisenPresentBookingCancel`. ContentView zeigt dasselbe Sheet. **Kein** blindes `openURL` mehr für Cancel.

Kontextmenüs: `BookingPortalCancelMenuItems` mit `onPresentCancel` — `TripDetailView`, `ContentView` (beide), `OffenTab`, `TripDetailIOS`.

- [ ] **Step 4: GREEN + Compile**

Run:

```bash
swift test --filter bookingPortalCancel
swift test --filter bookingPortalCancellation
swift test --filter ProviderWebViewDisplay
bash ./Scripts/ci-build.sh --arch arm64
bash ./Scripts/generate-ios-project.sh
bash ./Scripts/ios-test.sh
```

`ci-build.sh` sieht `ReiseniOS` nicht. iOS-Compile/Tests über die Projektskripte (kein ad-hoc-`xcodebuild`). Expected: alle Exit 0.

- [ ] **Step 5: verification-before-completion (sichtbarer Weg)**

Ohne XCUI: macOS Debug-Build (`bash ./Scripts/build-app.sh --configuration debug` nur wenn der Implementer das Bundle starten kann). Checkliste (Ledger `stornieren-entry`):

1. Buchung mit Free-Frist + Session: Inspector zeigt **Stornieren** (destruktiv), Tap öffnet Sheet mit Portal-Seite, nicht Safari.
2. Dieselbe Buchung-URL = Öffnen-URL: Sheet lädt die Buchungsseite.
3. Store-Pfad / Hub ohne WebView + gleiche URL: kein Stornieren.
4. Eigene Storno-URL ohne WebView: System-Browser.
5. Sheet schließen: Sync-Host zeigt die WebView wieder; Buchung nicht `cancelled`.
6. Sheet-Load-Fehler (offline / ungültiger Host): roter Text im Sheet, kein Safari.

Ergebnis ins Ledger `interfaces.inventory[stornieren-entry].verified` nur nach diesem Lauf oder nach den Unit-Evidence-Tests plus dokumentiertem Harness-Skip, wenn kein GUI-Run möglich ist — dann `open_gaps` nicht fälschlich schließen; Outer-Judge entscheidet.

- [ ] **Step 6: Commit**

```bash
git add Sources/ReisenSharedUI/BookingPortalOpenLink.swift \
  Sources/ReisenSharedUI/BookingPortalCancelSheetChrome.swift \
  Tests/ReisenSharedUITests/BookingPortalCancelChromeTests.swift \
  Sources/Reisen/App/BookingPortalCancelSheetHost.swift \
  Sources/Reisen/App/BookingPortalOpenCommandState.swift \
  Sources/Reisen/App/ReisenCommands.swift \
  Sources/Reisen/App/ContentView.swift \
  Sources/Reisen/App/BookingDetailContent.swift \
  Sources/Reisen/App/TripDetailView.swift \
  Sources/Reisen/Platform/ProviderSessionView.swift \
  Sources/Reisen/App/SyncView.swift \
  Sources/Reisen/App/ProviderSessionProbeHost.swift \
  Sources/Reisen/App/ProviderSyncContainer.swift \
  Apps/ReiseniOS/ProviderSync/WebViewHost.swift \
  Apps/ReiseniOS/ProviderSync/SyncTab.swift \
  Apps/ReiseniOS/ProviderSync/GlobalChrome.swift \
  Apps/ReiseniOS/Shared/BookingDetailIOS.swift \
  Apps/ReiseniOS/Shared/OffenTab.swift \
  Apps/ReiseniOS/Shared/TripDetailIOS.swift \
  Apps/ReiseniOS/Shared/BookingPortalCancelSheetHostIOS.swift
git commit -m "$(cat <<'EOF'
feat: open provider cancel in the session sheet

The destructive Stornieren control reuses the hub WebView; Safari stays a fallback for a distinct cancel URL without a session.
EOF
)"
```

Nur tatsächlich geänderte Pfade stagen (iOS-Kontextmenü-Dateien analog, wenn angefasst).

---

## Spec coverage (self-review)

| Spec | Task |
|------|------|
| Fristen in `isActionable` | 1 |
| gleiche URL actionable | 1 |
| Presentation sheet/safari/hidden | 1 |
| Hash-Fragment | 1 |
| Titel Stornieren + destructive | 2 + 4 |
| Display-Owner | 3 + 4 |
| Sheet load / Fehler / kein Safari | 4 |
| Dismiss → syncHost, URL nicht restaurieren | 4 |
| Entry ActionBar/Menü/Command inkl. OffenTab + TripDetailIOS | 4 |
| iOS resolveWebView (kein zweites WKWebView) | 4 |
| MenuButton ohne openURL bei sheet | 4 |
| Store-iOS = keine WebView | 1 + 4 (`hasSessionWebView`) |
| Kein Extract / kein XCUI / kein API-Storno | bewusst kein Task |

## Type consistency

- `isActionable` / `presentation` / `visible` teilen `deadlines: [CancellationDeadline]`, `now: Date`, `hasSessionWebView: Bool`.
- `BookingPortalCancelPresentation` nur `.sheet` / `.safari` / `.hidden`.
- Owner-API: `setWebViewDisplayOwner`, `allowsEmbed(on:)`.
- Cancel-Callback: `(BookingPortalCancelPresentation, URL) -> Void`.
