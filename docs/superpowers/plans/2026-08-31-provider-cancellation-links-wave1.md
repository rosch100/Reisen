# Provider Cancellation Links (Wave 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status (shipped):** Wave 1 ist umgesetzt. Historische Task-Snippets unten erwähnen teils noch `requiresProviderSession: Bool` an `presentation`/`visible`. **Live-SSOT:** Parameter `linkMode: ProviderCancellationLinkMode` (`.none` → hidden zuerst); Spec `docs/superpowers/specs/2026-08-31-provider-cancellation-links-all-design.md` + Code. Policy-Helper `requiresProviderSession(mode:)` bleibt intern.

**Goal:** Wire Hybrid Storno-Modes so GetYourGuide (in-page) and billiger-mietwagen (session-bound distinct URL) persist actionable `cancellationUrl`s, with Policy-SSOT and Sheet-only presentation where Safari would be useless or duplicate Open.

**Architecture:** Domain `ProviderCancellationLinkPolicy` owns mode per `(ProviderID, BookingType)`. Extract sets `cancellationUrl` accordingly. `BookingPortalCancellation.presentation` / `visible` take `linkMode` (session-bound / in-page never fall through to Safari; `.none` stays hidden). SharedUI hides copy-cancel when `cancel == open`.

**Tech Stack:** Swift 6 / Swift Testing / SPM targets `ReisenDomain`, `ReisenGetYourGuide`, `ReisenBilligerMietwagen`, `ReisenSharedUI`, macOS `Reisen` app.

## Global Constraints

- Spec SSOT: `docs/superpowers/specs/2026-08-31-provider-cancellation-links-all-design.md`
- No guessed Opodo `funnel=` / Booking `cancel.html` / Airbnb Stay cancel paths (Wave 2 / `none`)
- No SwiftData schema change; Upsert nil does not wipe persisted URL
- Deadline gate unchanged (`deadlinesForDisplay` must be non-empty for actionable)
- Tests: `swift test --filter <name>`; commits without Cursor co-author trailer
- Airbnb Stay uses `BookingType.hotel`; Experience uses `.activity`

## File map

| File | Role |
|------|------|
| `Sources/ReisenDomain/Services/ProviderCancellationLinkPolicy.swift` | Create — mode + `requiresProviderSession(mode:)` |
| `Sources/ReisenDomain/Services/BookingPortalCancellation.swift` | Add `requiresProviderSession` + `allowsCopyingCancellationLink` |
| `Tests/ReisenDomainTests/ProviderCancellationLinkPolicyTests.swift` | Create |
| `Tests/ReisenDomainTests/BookingPortalCancellationTests.swift` | Extend presentation/copy |
| `Sources/ReisenGetYourGuide/GetYourGuideMyBookingsParser.swift` | Set in-page `cancellationUrl` |
| `Tests/ReisenGetYourGuideTests/ParserTests.swift` | Expect URL == externalUrl |
| `Sources/ReisenBilligerMietwagen/BilligerMietwagenWebConstants.swift` | `cancellationPageURL` SSOT |
| `Sources/ReisenBilligerMietwagen/BilligerMietwagenBookingsParser.swift` | Set session-bound URL |
| `Tests/ReisenBilligerMietwagenTests/ParserTests.swift` | Expect cancellation ≠ open |
| `Sources/ReisenSharedUI/BookingPortalOpenLink.swift` | Pass session flag; gate copy menu |
| `Sources/Reisen/App/BookingPortalOpenCommandState.swift` | Pass session flag from policy |
| `Sources/Reisen/App/ContentView.swift` | Pass session flag |
| `Apps/ReiseniOS/Shared/BookingDetailIOS.swift` | Pass `requiresProviderSession` into ActionBar |
| `Apps/ReiseniOS/Shared/OffenTab.swift` | Same |
| `Apps/ReiseniOS/Shared/TripDetailIOS.swift` | Same |

---

### Task 1: ProviderCancellationLinkPolicy (Domain SSOT)

**Files:**
- Create: `Sources/ReisenDomain/Services/ProviderCancellationLinkPolicy.swift`
- Create: `Tests/ReisenDomainTests/ProviderCancellationLinkPolicyTests.swift`

**Interfaces:**
- Consumes: `ProviderID`, `BookingType`
- Produces:
  - `public enum ProviderCancellationLinkMode: Equatable, Sendable { case distinctURL, inPageOnOpen, sessionBoundDistinct, none }`
  - `public enum ProviderCancellationLinkPolicy`
  - `static func mode(provider: ProviderID, bookingType: BookingType) -> ProviderCancellationLinkMode`
  - `static func requiresProviderSession(_ mode: ProviderCancellationLinkMode) -> Bool` — true for `.inPageOnOpen` and `.sessionBoundDistinct`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import ReisenDomain

@Test func providerCancellationLinkPolicy_wave1Modes() {
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .traveloka, bookingType: .hotel)
            == .distinctURL
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .airbnb, bookingType: .activity)
            == .distinctURL
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .airbnb, bookingType: .hotel)
            == .none
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .getYourGuide, bookingType: .activity)
            == .inPageOnOpen
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .billigerMietwagen, bookingType: .carRental)
            == .sessionBoundDistinct
    )
    for type in BookingType.allCases {
        #expect(ProviderCancellationLinkPolicy.mode(provider: .opodo, bookingType: type) == .none)
        #expect(ProviderCancellationLinkPolicy.mode(provider: .booking, bookingType: type) == .none)
        #expect(ProviderCancellationLinkPolicy.mode(provider: .check24, bookingType: type) == .none)
    }
}

@Test func providerCancellationLinkPolicy_requiresProviderSession() {
    #expect(ProviderCancellationLinkPolicy.requiresProviderSession(.inPageOnOpen))
    #expect(ProviderCancellationLinkPolicy.requiresProviderSession(.sessionBoundDistinct))
    #expect(!ProviderCancellationLinkPolicy.requiresProviderSession(.distinctURL))
    #expect(!ProviderCancellationLinkPolicy.requiresProviderSession(.none))
}

@Test func providerCancellationLinkPolicy_coversAllSyncProviders() {
    for provider in ProviderID.syncProviderIDs {
        for type in BookingType.allCases {
            _ = ProviderCancellationLinkPolicy.mode(provider: provider, bookingType: type)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter providerCancellationLinkPolicy_wave1Modes`

Expected: FAIL (type `ProviderCancellationLinkPolicy` not found)

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public enum ProviderCancellationLinkMode: Equatable, Sendable {
    case distinctURL
    case inPageOnOpen
    case sessionBoundDistinct
    case none
}

public enum ProviderCancellationLinkPolicy {
    public static func mode(provider: ProviderID, bookingType: BookingType) -> ProviderCancellationLinkMode {
        switch provider {
        case .traveloka:
            return .distinctURL
        case .airbnb:
            return bookingType == .activity ? .distinctURL : .none
        case .getYourGuide:
            return .inPageOnOpen
        case .billigerMietwagen:
            return .sessionBoundDistinct
        case .check24, .opodo, .booking, .manual:
            return .none
        default:
            return .none
        }
    }

    public static func requiresProviderSession(_ mode: ProviderCancellationLinkMode) -> Bool {
        switch mode {
        case .inPageOnOpen, .sessionBoundDistinct: return true
        case .distinctURL, .none: return false
        }
    }
}
```

Note: `manual` is not in `syncProviderIDs`; Editor HTTPS remains distinct via user field. Policy returns `.distinctURL` for `.manual` (not `.none`).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter providerCancellationLinkPolicy`

Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/Services/ProviderCancellationLinkPolicy.swift \
  Tests/ReisenDomainTests/ProviderCancellationLinkPolicyTests.swift
git commit -m "feat: add ProviderCancellationLinkPolicy SSOT for storno modes"
```

---

### Task 2: Presentation requiresProviderSession + copy helper

**Files:**
- Modify: `Sources/ReisenDomain/Services/BookingPortalCancellation.swift`
- Modify: `Tests/ReisenDomainTests/BookingPortalCancellationTests.swift`
- Modify call sites (default `false` first, then wire in Task 5):
  - `Sources/ReisenSharedUI/BookingPortalOpenLink.swift`
  - `Sources/Reisen/App/BookingPortalOpenCommandState.swift`
  - `Sources/Reisen/App/ContentView.swift`
  - `Tests/ReisenSharedUITests/BookingPortalCancelChromeTests.swift`

**Interfaces:**
- Consumes: Task 1 modes (call sites later)
- Produces:
  - `presentation(..., hasSessionWebView: Bool, requiresProviderSession: Bool = false)`
  - `visible(..., hasSessionWebView: Bool, requiresProviderSession: Bool = false)`
  - `allowsCopyingCancellationLink(cancel: URL?, open: URL?) -> Bool`

- [ ] **Step 1: Write the failing tests** (append to `BookingPortalCancellationTests.swift`)

```swift
@Test func bookingPortalCancellation_presentation_sessionBoundHidesSafari() {
    let deadlines = [freeDeadline()]
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: false,
            requiresProviderSession: true
        ) == .hidden
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: true,
            requiresProviderSession: true
        ) == .sheet
    )
}

@Test func bookingPortalCancellation_allowsCopyingCancellationLink() {
    #expect(
        BookingPortalCancellation.allowsCopyingCancellationLink(cancel: cancel, open: open)
    )
    #expect(
        !BookingPortalCancellation.allowsCopyingCancellationLink(cancel: open, open: open)
    )
    #expect(
        !BookingPortalCancellation.allowsCopyingCancellationLink(cancel: nil, open: open)
    )
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter bookingPortalCancellation_presentation_sessionBoundHidesSafari`

Expected: FAIL (extra argument / unknown method)

- [ ] **Step 3: Write minimal implementation**

In `BookingPortalCancellation.swift`, replace `presentation` / `visible` and add helper:

```swift
public static func presentation(
    cancellation: URL?,
    open: URL?,
    status: BookingStatus,
    deadlines: [CancellationDeadline],
    now: Date,
    hasSessionWebView: Bool,
    requiresProviderSession: Bool = false
) -> BookingPortalCancelPresentation {
    guard isActionable(
        cancellation: cancellation,
        open: open,
        status: status,
        deadlines: deadlines,
        now: now
    ) else { return .hidden }
    if hasSessionWebView { return .sheet }
    if requiresProviderSession { return .hidden }
    if cancellation != open { return .safari }
    return .hidden
}

public static func allowsCopyingCancellationLink(cancel: URL?, open: URL?) -> Bool {
    guard let cancel else { return false }
    return cancel != open
}

// visible: add requiresProviderSession: Bool = false and pass through to presentation
```

Update every existing `presentation`/`visible` call to compile (default param keeps most calls working if Swift default applies at call site — add the parameter explicitly in SharedUI/App when touching those files in Task 5; for this task, ensure tests and Domain compile).

- [ ] **Step 4: Run tests**

Run: `swift test --filter BookingPortalCancellation`

Expected: PASS (including existing presentation tests with default `requiresProviderSession: false`)

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/Services/BookingPortalCancellation.swift \
  Tests/ReisenDomainTests/BookingPortalCancellationTests.swift
git commit -m "feat: gate session-bound cancel presentation and copy-link helper"
```

---

### Task 3: GetYourGuide in-page cancellationUrl

**Files:**
- Modify: `Sources/ReisenGetYourGuide/GetYourGuideMyBookingsParser.swift` (Facts in `mapBooking`)
- Modify: `Tests/ReisenGetYourGuideTests/ParserTests.swift` (`gygMyBookingsParsesUpcomingActivityDrafts`)

**Interfaces:**
- Consumes: `externalUrl` string already built; Policy mode `.inPageOnOpen` (documentation; parser sets equality directly)
- Produces: `draft.cancellationUrl == draft.externalUrl` when Open URL present

- [ ] **Step 1: Write the failing test**

In `gygMyBookingsParsesUpcomingActivityDrafts`, replace:

```swift
#expect(draft.cancellationUrl == nil)
```

with:

```swift
#expect(draft.cancellationUrl == draft.externalUrl)
#expect(draft.cancellationUrl == GetYourGuideWebConstants.bookingURL(hash: "<REDACTED-1>"))
```

Also add to `gygMyBookingsParsesPastWhenUpcomingEmpty` after externalUrl expect:

```swift
#expect(draft.cancellationUrl == draft.externalUrl)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter gygMyBookingsParsesUpcomingActivityDrafts`

Expected: FAIL (`cancellationUrl` is nil / not equal)

- [ ] **Step 3: Write minimal implementation**

In `mapBooking`, after building `externalUrl`:

```swift
let externalUrl = GetYourGuideWebConstants.bookingURL(hash: hash)
return DraftAssembler.draft(
    from: ProviderBookingFacts(
        // ... existing fields ...
        externalUrl: externalUrl,
        cancellationUrl: externalUrl,
        // ... rest unchanged ...
    )
)
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter ReisenGetYourGuideTests`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenGetYourGuide/GetYourGuideMyBookingsParser.swift \
  Tests/ReisenGetYourGuideTests/ParserTests.swift
git commit -m "feat: set GYG cancellationUrl to booking open URL for in-page cancel"
```

---

### Task 4: billiger-mietwagen session-bound cancellation URL

**Files:**
- Modify: `Sources/ReisenBilligerMietwagen/BilligerMietwagenWebConstants.swift`
- Modify: `Sources/ReisenBilligerMietwagen/BilligerMietwagenBookingsParser.swift`
- Modify: `Tests/ReisenBilligerMietwagenTests/ParserTests.swift` (`bmBookingsParsesActiveCarRentalDraft`)

**Interfaces:**
- Consumes: `BilligerMietwagenAuthConstants.origin` via existing `origin` private in WebConstants
- Produces: `static var cancellationPageURLString: String` / `cancellationPageURL: String` = `"\(origin)/reservation/cancellation"`

- [ ] **Step 1: Write the failing test**

Replace `#expect(draft.cancellationUrl == nil)` with:

```swift
#expect(
    draft.cancellationUrl
        == BilligerMietwagenWebConstants.cancellationPageURL
)
#expect(draft.cancellationUrl != draft.externalUrl)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter bmBookingsParsesActiveCarRentalDraft`

Expected: FAIL (nil or missing symbol)

- [ ] **Step 3: Write minimal implementation**

In `BilligerMietwagenWebConstants.swift`:

```swift
/// Live-Beleg Sheet-Spec: SPA Cancel ohne Buchungs-ID; Session-Cookies erforderlich.
static var cancellationPageURL: String {
    "\(origin)/reservation/cancellation"
}
```

In `mapItem` Facts:

```swift
externalUrl: BilligerMietwagenWebConstants.bookingPageURL(id: id),
cancellationUrl: BilligerMietwagenWebConstants.cancellationPageURL,
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter ReisenBilligerMietwagenTests`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenBilligerMietwagen/BilligerMietwagenWebConstants.swift \
  Sources/ReisenBilligerMietwagen/BilligerMietwagenBookingsParser.swift \
  Tests/ReisenBilligerMietwagenTests/ParserTests.swift
git commit -m "feat: persist billiger-mietwagen session-bound cancellation URL"
```

---

### Task 5: Wire requiresProviderSession + copy menu in UI

**Files:**
- Modify: `Sources/ReisenSharedUI/BookingPortalOpenLink.swift` (`BookingPortalActionBar`, `BookingPortalCancelMenuItems`)
- Modify: `Sources/Reisen/App/BookingPortalOpenCommandState.swift`
- Modify: `Sources/Reisen/App/ContentView.swift` (presentation call ~line 122)
- Modify: `Tests/ReisenSharedUITests/BookingPortalCancelChromeTests.swift`
- Grep iOS (`Apps/ReiseniOS`) for `hasSessionWebView` / `BookingPortalActionBar` and pass the same flag

**Interfaces:**
- Consumes: `ProviderCancellationLinkPolicy.mode` + `requiresProviderSession`
- Produces: UI that passes `requiresProviderSession: ProviderCancellationLinkPolicy.requiresProviderSession(ProviderCancellationLinkPolicy.mode(provider:bookingType:))`

Helper to avoid duplication (optional small extension on Booking in Domain or local in SharedUI):

```swift
// Prefer keep in Domain next to Policy:
extension ProviderCancellationLinkPolicy {
    public static func requiresProviderSession(provider: ProviderID, bookingType: BookingType) -> Bool {
        requiresProviderSession(mode(provider: provider, bookingType: bookingType))
    }
}
```

Add in Task 5 Step 3 if not already present from Task 1.

- [ ] **Step 1: Write / extend failing UI test**

In `BookingPortalCancelChromeTests.swift`, add assertion path that `visible` with `requiresProviderSession: true` and `hasSessionWebView: false` yields `cancel == nil` even when cancel URL ≠ open (mirror Domain test at SharedUI call site if the bar takes the new param).

If ActionBar gains `requiresProviderSession` / `provider`+`bookingType`, add:

```swift
@Test func bookingPortalActionBar_hidesCopyCancelWhenSameURL() {
    // Construct bar inputs where shown.cancel == shown.open;
    // assert contextMenu would not offer copy — if hard to UI-test,
    // unit-test allowsCopyingCancellationLink only (already Task 2)
    // and assert ActionBar code uses the helper (review gate).
    #expect(
        !BookingPortalCancellation.allowsCopyingCancellationLink(
            cancel: URL(string: "https://example.com/x")!,
            open: URL(string: "https://example.com/x")!
        )
    )
}
```

- [ ] **Step 2: Run filter (may already pass helper; fail if ActionBar API missing)**

Run: `swift test --filter bookingPortalActionBar_hidesCopyCancelWhenSameURL`

- [ ] **Step 3: Implement wiring**

1. Add convenience on Policy (if missing):

```swift
public static func requiresProviderSession(provider: ProviderID, bookingType: BookingType) -> Bool {
    requiresProviderSession(mode(provider: provider, bookingType: bookingType))
}
```

2. `BookingPortalActionBar`: add `var requiresProviderSession: Bool` (or `provider` + `bookingType` and compute inside). Pass into every `visible` / `presentation` call.

3. Context menu:

```swift
if let url = shown.cancel,
   BookingPortalCancellation.allowsCopyingCancellationLink(cancel: url, open: shown.open) {
    CopyLinkMenuItem(url: url, title: L10n.string(.actionCopyCancellationLink))
}
```

4. `BookingPortalOpenCommandState`: add `requiresProviderSession: Bool = false`; pass to `presentation`.

5. Call sites that build ActionBar / command state: set  
   `requiresProviderSession: ProviderCancellationLinkPolicy.requiresProviderSession(provider: booking.provider, bookingType: booking.bookingType)`.

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter BookingPortalCancellation
swift test --filter BookingPortalCancelChrome
swift test --filter providerCancellationLinkPolicy
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/Services/ProviderCancellationLinkPolicy.swift \
  Sources/ReisenSharedUI/BookingPortalOpenLink.swift \
  Sources/Reisen/App/BookingPortalOpenCommandState.swift \
  Sources/Reisen/App/ContentView.swift \
  Apps/ReiseniOS \
  Tests/ReisenSharedUITests/BookingPortalCancelChromeTests.swift
git commit -m "feat: wire session-bound cancel flag and hide duplicate copy-cancel"
```

---

### Task 6: Regression + docs sanity

**Files:**
- Verify only (docs already updated on branch `docs/provider-cancellation-links-all`):  
  `docs/dev/booking-portal-open.md`, hybrid + portal + sheet specs
- No code unless Airbnb Experience still missing on merge base (PR #98) — if `cancellationUrl` still nil for Experience on current branch tip, do **not** re-implement here; depend on merged #98 or cherry-pick separately

- [ ] **Step 1: Run focused regression suite**

```bash
swift test --filter airbnbTripListMapsExperienceToActivity
swift test --filter ReisenTravelokaTests
swift test --filter gygMyBookingsParsesUpcomingActivityDrafts
swift test --filter bmBookingsParsesActiveCarRentalDraft
swift test --filter providerCancellationLinkPolicy
swift test --filter BookingPortalCancellation
```

Expected: All PASS. If Experience test still expects nil on this branch, note blocker: merge/rebase onto master that includes PR #98 first.

- [ ] **Step 2: Confirm Opodo/Booking/Check24 still nil**

```bash
swift test --filter ReisenOpodoTests
# or targeted parser tests that assert cancellationUrl == nil
```

Expected: existing `cancellationUrl == nil` assertions still PASS

- [ ] **Step 3: Commit** only if Step 1 required a rebase note file — otherwise no commit. If branch needs rebase onto master with #98:

```bash
git fetch origin && git rebase origin/master
# resolve conflicts; re-run Step 1
```

- [ ] **Step 4: Final status**

```bash
git status -sb
git log --oneline origin/master..HEAD
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Policy `mode(provider:bookingType:)` | 1 |
| sessionBoundDistinct / inPage presentation | 2 + 5 |
| allowsCopyingCancellationLink | 2 + 5 |
| GYG inPage extract | 3 |
| BM cancellation URL | 4 |
| Opodo/Booking/Check24/Stay remain none | 1 + 6 |
| Docs matrix | already on docs branch; Task 6 verify |
| No schema enum | all tasks |
| Wave 2 out of scope | no tasks |

## Placeholder scan

None intentional. Call-site list for Task 5 must be re-grepped at execution time for `hasSessionWebView` / `BookingPortalActionBar(`.
