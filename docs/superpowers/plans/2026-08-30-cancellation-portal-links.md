# Storno-Portal-Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jeder Sync-Provider kann eine belegte Storno-URL persistieren; die UI öffnet Öffnen-URL und Storno-URL über zwei HIG-Buttons, ohne in Reisen zu stornieren.

**Architecture:** Optionales `cancellationUrl` in Domain → Draft/Enrichment/Upsert → `SDBooking`. Filter nur `BookingExternalURL.browserURL`. SharedUI `BookingPortalActionBar` (Link + Button-Stil). Provider setzen die URL nur mit Fixture-/HAR-Beleg; sonst `nil`.

**Tech Stack:** Swift, Swift Testing, SwiftData, SwiftUI, bestehendes `openURL`.

## Global Constraints

- SSOT-Filter: `BookingExternalURL.browserURL` — kein zweites URL-Policy-Enum.
- Storno-URL nie aus `externalUrl` kopieren; UI-Guard `BookingPortalCancellation.isActionable`.
- Kein `role: .destructive`, kein Confirm für Storno-Button.
- L10n nur `L10nKey` + `Localizable.xcstrings` DE+EN.
- Schema: optionales Attribut, `Schema(ReisenSchemaV9.models)`, kein Wipe-Happy-Path.
- Testlauf TDD: `swift test --filter <Name>` im Worktree-Root. CI-Parität später: `bash ./Scripts/ci-test.sh`.
- Kein ad-hoc-`xcodebuild`. Kein Commit von `*.xcodeproj`.

## File map

- Create: `Sources/ReisenDomain/Services/BookingPortalCancellation.swift`
- Create: `Sources/ReisenDomain/Entities/BookingPortalCancelTitle.swift`
- Create: `Tests/ReisenDomainTests/BookingPortalCancellationTests.swift`
- Create: `Tests/ReisenDomainTests/BookingPortalCancelTitleTests.swift`
- Modify: `Sources/ReisenDomain/Entities/Booking.swift` — Feld + `cancellationBrowserURL`
- Modify: `Sources/ReisenDomain/Entities/ProviderDrafts.swift` — Draft + Enrichment
- Modify: `Sources/ReisenDomain/Sync/ProviderBookingFacts.swift`
- Modify: `Sources/ReisenDomain/Sync/DraftAssembler.swift`
- Modify: `Sources/ReisenDomain/Entities/ProviderBookingDraft+Enrichment.swift`
- Modify: `Sources/ReisenDomain/UseCases/SyncBookingDraftFieldCopy.swift`
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Modify: `Sources/ReisenData/Models/SDBooking.swift`
- Modify: `Sources/ReisenData/Mapping/DomainMapper+Booking.swift`
- Modify: `Sources/ReisenData/Persistence/SwiftDataBookingFieldApply+Scalars.swift`
- Modify: `Sources/ReisenData/Schema/PersistenceBootstrap+LegacyBookingCopy.swift`
- Modify: `Sources/ReisenSharedUI/BookingPortalOpenLink.swift` — ActionBar
- Modify: `Sources/ReisenSharedUI/BookingEditor.swift`
- Modify: `Sources/Reisen/App/BookingDetailContent.swift`, `TripDetailView.swift`, `ContentView.swift`, `ReisenCommands.swift`, `BookingPortalOpenCommandState.swift`
- Modify: `Apps/ReiseniOS/Shared/BookingDetailIOS.swift`, `TripDetailIOS.swift`, `OffenTab.swift`
- Modify: `Sources/ReisenTraveloka/TravelokaItineraryEntryParser.swift`
- Modify: provider parsers (Check24, Booking.com, Airbnb, GYG, Opodo, billiger-mietwagen) nur wenn Beleg
- Modify: `docs/dev/booking-portal-open.md`
- Test: `Tests/ReisenDomainTests/BookingExternalURLTests.swift`, `Tests/ReisenTravelokaTests/ParserTests.swift`, `Tests/ReisenDataTests/BookingUpsertStabilityTests.swift`, jeweilige Provider-Parser-Tests

---

### Task 1: Domain-Feld und Actionable-Guard

**Files:**
- Modify: `Sources/ReisenDomain/Entities/Booking.swift`
- Create: `Sources/ReisenDomain/Services/BookingPortalCancellation.swift`
- Create: `Tests/ReisenDomainTests/BookingPortalCancellationTests.swift`
- Modify: `Tests/ReisenDomainTests/BookingExternalURLTests.swift`

**Interfaces:**
- Consumes: `BookingExternalURL.browserURL`
- Produces: `Booking.cancellationUrl: String?`, `Booking.cancellationBrowserURL: URL?`, `BookingPortalCancellation.isActionable`, `BookingPortalActions.visible(open:cancellation:status:) -> (open: URL?, cancel: URL?)`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/ReisenDomainTests/BookingPortalCancellationTests.swift
import Foundation
import Testing
import ReisenDomain

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

@Test func bookingPortalActions_visible_coversOnlyCancelAndNeither() {
    let open = URL(string: "https://example.com/open")!
    let cancel = URL(string: "https://example.com/cancel")!
    let both = BookingPortalActions.visible(open: open, cancellation: cancel, status: .confirmed)
    #expect(both.open == open && both.cancel == cancel)
    let onlyCancel = BookingPortalActions.visible(open: nil, cancellation: cancel, status: .confirmed)
    #expect(onlyCancel.open == nil && onlyCancel.cancel == cancel)
    let neither = BookingPortalActions.visible(open: nil, cancellation: nil, status: .confirmed)
    #expect(neither.open == nil && neither.cancel == nil)
    let cancelled = BookingPortalActions.visible(open: open, cancellation: cancel, status: .cancelled)
    #expect(cancelled.open == open && cancelled.cancel == nil)
    let same = BookingPortalActions.visible(open: open, cancellation: open, status: .confirmed)
    #expect(same.open == open && same.cancel == nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter bookingCancellationBrowserURL --filter bookingPortalActions_visible`
Expected: FAIL (type `Booking` has no member `cancellationUrl` / `BookingPortalActions` missing)

- [ ] **Step 3: Write minimal implementation**

In `Booking.swift`: add `public var cancellationUrl: String?` to stored properties, init (default `nil`), assignment in init, and:

```swift
public var cancellationBrowserURL: URL? {
    BookingExternalURL.browserURL(from: cancellationUrl)
}
```

Create `BookingPortalCancellation.swift`:

```swift
import Foundation

public enum BookingPortalCancellation {
    public static func isActionable(
        cancellation: URL?,
        open: URL?,
        status: BookingStatus
    ) -> Bool {
        guard status != .cancelled, let cancellation else { return false }
        return cancellation != open
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
        status: BookingStatus
    ) -> Visible {
        Visible(
            open: open,
            cancel: BookingPortalCancellation.isActionable(
                cancellation: cancellation,
                open: open,
                status: status
            ) ? cancellation : nil
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter bookingCancellationBrowserURL --filter bookingPortalActions_visible`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/Entities/Booking.swift \
  Sources/ReisenDomain/Services/BookingPortalCancellation.swift \
  Tests/ReisenDomainTests/BookingPortalCancellationTests.swift
git commit -m "$(cat <<'EOF'
feat: persist optional cancellation URL on Booking

EOF
)"
```

---

### Task 2: Draft-Pipeline (Facts → Assembler → Enrichment → Upsert-Copy)

**Files:**
- Modify: `Sources/ReisenDomain/Sync/ProviderBookingFacts.swift`
- Modify: `Sources/ReisenDomain/Entities/ProviderDrafts.swift`
- Modify: `Sources/ReisenDomain/Sync/DraftAssembler.swift`
- Modify: `Sources/ReisenDomain/Entities/ProviderBookingDraft+Enrichment.swift`
- Modify: `Sources/ReisenDomain/UseCases/SyncBookingDraftFieldCopy.swift`
- Modify: `Tests/ReisenDomainTests/DraftAssemblerTests.swift` (neue Tests ans Dateiende)
- Modify: `Tests/ReisenDomainTests/SyncProviderBookingsUpsertTests.swift` (ein Assert am bestehenden Keep-Draft)

**Interfaces:**
- Consumes: `Booking.cancellationUrl`
- Produces: `ProviderBookingFacts.cancellationUrl`, `ProviderBookingDraft.cancellationUrl`, `ProviderBookingEnrichment.cancellationUrl`; `assignNonEmpty` für Enrich; `SyncBookingDraftFieldCopy` schreibt auf `Booking`

- [ ] **Step 1: Write the failing tests**

```swift
@Test func draftAssembler_copiesCancellationUrl() {
    let facts = ProviderBookingFacts(
        provider: .traveloka,
        bookingType: .hotel,
        start: .instant(Date(timeIntervalSince1970: 10)),
        end: .instant(Date(timeIntervalSince1970: 20)),
        externalUrl: "https://www.traveloka.com/en-en/item/details/b?type=HOTEL&id=i",
        cancellationUrl: "https://www.traveloka.com/en-en/refund/presubmission/HOTEL/b/i"
    )
    let draft = try #require(DraftAssembler.draft(from: facts))
    #expect(draft.cancellationUrl == facts.cancellationUrl)
}

@Test func draftEnrichment_assignNonEmptyCancellationUrl_doesNotClearCatalog() {
    var draft = ProviderBookingDraft(
        provider: .traveloka,
        bookingType: .hotel,
        externalUrl: "https://example.com/open",
        startAt: Date(timeIntervalSince1970: 10),
        endAt: Date(timeIntervalSince1970: 20),
        cancellationUrl: "https://example.com/cancel"
    )
    draft.apply(ProviderBookingEnrichment())
    #expect(draft.cancellationUrl == "https://example.com/cancel")
    draft.apply(ProviderBookingEnrichment(cancellationUrl: "https://example.com/cancel2"))
    #expect(draft.cancellationUrl == "https://example.com/cancel2")
}
```

`TemporalFact` ist ein Enum: `.instant(Date)` wie in `draftAssembler_instantFacts_buildDraftWithoutCrash`.

Zusätzlich in `missingDeadlinesStillPrunesAbsentBookings`: am Keep-Draft `cancellationUrl: "https://example/opodo/cancel"` setzen und `#expect(repo.all.first?.cancellationUrl == "https://example/opodo/cancel")`.

Neuer Test: bestehendes Booking mit `cancellationUrl`, Draft ohne Feld → URL bleibt:

```swift
@Test func syncDraftCopy_nilCancellationUrlDoesNotWipeExisting() {
    var booking = Booking(
        provider: .opodo,
        bookingType: .hotel,
        cancellationUrl: "https://example.com/cancel",
        startAt: Date(timeIntervalSince1970: 10),
        endAt: Date(timeIntervalSince1970: 20)
    )
    let draft = ProviderBookingDraft(
        provider: .opodo,
        bookingType: .hotel,
        externalUrl: "https://example.com/open",
        startAt: Date(timeIntervalSince1970: 10),
        endAt: Date(timeIntervalSince1970: 20)
    )
    SyncBookingDraftFieldCopy.applyCoreFields(from: draft, onto: &booking, now: Date(timeIntervalSince1970: 30))
    #expect(booking.cancellationUrl == "https://example.com/cancel")
}
```

Parameterreihenfolge von `Booking(...)` an den Ist-Init anpassen (`cancellationUrl` steht nach `externalUrl`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter draftAssembler_copiesCancellationUrl --filter draftEnrichment_assignNonEmptyCancellationUrl --filter missingDeadlinesStillPrunesAbsentBookings`
Expected: FAIL (extra argument / missing property)

- [ ] **Step 3: Write minimal implementation**

Add `cancellationUrl: String? = nil` to Facts, Draft, Enrichment inits and stored properties.

`DraftAssembler.draft`: `cancellationUrl: facts.cancellationUrl`.

`DraftAssembler.enrichment`: `cancellationUrl: facts.cancellationUrl` (nil bleibt nil; `apply` nutzt `assignNonEmpty`).

In `apply(_ enrichment:)`:

```swift
assignNonEmpty(enrichment.cancellationUrl, to: \.cancellationUrl)
```

In `SyncBookingDraftFieldCopy.applyCoreFields` **nicht** `booking.cancellationUrl = draft.cancellationUrl` (nil würde Editor-URLs wischen). Stattdessen:

```swift
if let url = draft.cancellationUrl, BookingExternalURL.browserURL(from: url) != nil {
    booking.cancellationUrl = url
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: same filters as Step 2
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain Tests/ReisenDomainTests
git commit -m "$(cat <<'EOF'
feat: thread cancellation URL through draft upsert

EOF
)"
```

---

### Task 3: Persistenz (SwiftData + Mapper)

**Files:**
- Modify: `Sources/ReisenData/Models/SDBooking.swift`
- Modify: `Sources/ReisenData/Mapping/DomainMapper+Booking.swift`
- Modify: `Sources/ReisenData/Persistence/SwiftDataBookingFieldApply+Scalars.swift`
- Modify: `Sources/ReisenData/Schema/PersistenceBootstrap+LegacyBookingCopy.swift`
- Modify: `Tests/ReisenDataTests/BookingUpsertStabilityTests.swift`

**Interfaces:**
- Consumes: `Booking.cancellationUrl`
- Produces: `SDBooking.cancellationUrl`; Mapper-Roundtrip

- [ ] **Step 1: Write the failing test**

In `bookingUpsertKeepsChildIdentitiesInPlace` das erste `Booking(…)` um `cancellationUrl: "https://example.com/cancel"` ergänzen. Nach erstem Upsert und Fetch:

```swift
#expect(loaded.cancellationUrl == "https://example.com/cancel")
```

(`loaded` = das nach `repo.fetch` / Mapper geholte Domain-Objekt — denselben Fetch-Pfad nutzen, den der Test bereits für `title` prüft. Falls der Test nur Child-IDs prüft: nach `repo.upsert(first)` `DomainMapper.booking(from:)` auf das SD-Model anwenden oder `repo.fetch(id: bookingID)`.)

Konkret nach `try repo.upsert(first)`:

```swift
let stored = try #require(try repo.fetch(id: bookingID))
#expect(stored.cancellationUrl == "https://example.com/cancel")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter bookingUpsertKeepsChildIdentitiesInPlace`
Expected: FAIL (extra argument or stored nil)

- [ ] **Step 3: Write minimal implementation**

`SDBooking`: `public var cancellationUrl: String?` plus Init-Parameter default `nil` und `self.cancellationUrl = cancellationUrl`.

`applyIdentity`: `model.cancellationUrl = booking.cancellationUrl`.

`DomainMapper.booking(from:)`: `cancellationUrl: model.cancellationUrl`.

`makeLegacyBookingCopy`: `cancellationUrl: booking.cancellationUrl` (nach `externalUrl`).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter bookingUpsertKeepsChildIdentitiesInPlace`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenData Tests/ReisenDataTests/BookingUpsertStabilityTests.swift
git commit -m "$(cat <<'EOF'
feat: persist booking cancellation URL in SwiftData

EOF
)"
```

---

### Task 4: L10n und SharedUI-Action-Bar

**Files:**
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Create: `Sources/ReisenDomain/Entities/BookingPortalCancelTitle.swift`
- Create: `Tests/ReisenDomainTests/BookingPortalCancelTitleTests.swift`
- Modify: `Sources/ReisenSharedUI/BookingPortalOpenLink.swift`

**Interfaces:**
- Consumes: `BookingPortalCancellation.isActionable`, `BookingPortalOpenTitle`
- Produces: Keys `action.open_short`, `action.cancel_in_portal`, `action.cancel_in_portal_menu`, `action.cancel_in_portal_help`, `action.copy_cancellation_link`; `BookingPortalActionBar`; `BookingPortalCancelTitle`

- [ ] **Step 1: Write the failing title tests**

```swift
import Testing
import Foundation
@testable import ReisenDomain

@Test func bookingPortalCancelTitle_keysResolveInCatalog() {
    for key in [
        L10nKey.actionOpenShort,
        .actionCancelInPortal,
        .actionCancelInPortalMenu,
        .actionCancelInPortalHelp,
        .actionCopyCancellationLink,
    ] {
        let value = L10n.string(key)
        #expect(!value.isEmpty, "Key \(key.rawValue) leer")
        #expect(value != key.rawValue, "Key \(key.rawValue) nicht lokalisiert")
    }
    #expect(BookingPortalCancelTitle.button != L10nKey.actionCancelInPortal.rawValue)
    #expect(BookingPortalCancelTitle.menu != L10nKey.actionCancelInPortalMenu.rawValue)
    #expect(!BookingPortalCancelTitle.help.isEmpty)
}

@Test func bookingPortalOpenTitle_shortKeyResolves() {
    #expect(BookingPortalOpenTitle.short != L10nKey.actionOpenShort.rawValue)
    #expect(!BookingPortalOpenTitle.short.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter bookingPortalCancelTitle_keysResolveInCatalog --filter bookingPortalOpenTitle_shortKeyResolves`
Expected: FAIL (missing keys / types)

- [ ] **Step 3: Write keys, catalog, titles, ActionBar**

`L10nKey` (neben den Open-Cases):

```swift
case actionOpenShort = "action.open_short"
case actionCancelInPortal = "action.cancel_in_portal"
case actionCancelInPortalMenu = "action.cancel_in_portal_menu"
case actionCancelInPortalHelp = "action.cancel_in_portal_help"
case actionCopyCancellationLink = "action.copy_cancellation_link"
```

`Localizable.xcstrings` — fünf Keys, je `de`+`en`, `state: translated`:

| key | de | en |
|-----|----|----|
| action.open_short | Öffnen | Open |
| action.cancel_in_portal | Storno | Cancel in portal |
| action.cancel_in_portal_menu | Stornieren im Portal | Cancel in portal |
| action.cancel_in_portal_help | Öffnet die Stornoseite beim Anbieter. Storniert die Buchung nicht in Reisen. | Opens the provider’s cancellation page. Does not cancel the booking in Reisen. |
| action.copy_cancellation_link | Storno-Link kopieren | Copy cancellation link |

`BookingPortalOpenTitle.short` → `L10n.string(.actionOpenShort)`.

```swift
public enum BookingPortalCancelTitle {
    public static var button: String { L10n.string(.actionCancelInPortal) }
    public static var menu: String { L10n.string(.actionCancelInPortalMenu) }
    public static var help: String { L10n.string(.actionCancelInPortalHelp) }
}
```

In `BookingPortalOpenLink.swift` ergänzen:

```swift
public struct BookingPortalActionBar: View {
    let openURL: URL?
    let cancellationURL: URL?
    var status: BookingStatus
    var openTitle: String
    var openHelp: String?
    var openButtonStyle: BookingPortalOpenButtonStyle

    public enum BookingPortalOpenButtonStyle {
        case bordered
        case prominent
    }

    public init(
        openURL: URL?,
        cancellationURL: URL?,
        status: BookingStatus,
        openTitle: String,
        openHelp: String? = nil,
        openButtonStyle: BookingPortalOpenButtonStyle
    ) {
        self.openURL = openURL
        self.cancellationURL = cancellationURL
        self.status = status
        self.openTitle = openTitle
        self.openHelp = openHelp
        self.openButtonStyle = openButtonStyle
    }

    public var body: some View {
        let shown = BookingPortalActions.visible(
            open: openURL,
            cancellation: cancellationURL,
            status: status
        )
        HStack(spacing: 8) {
            if let open = shown.open {
                Link(destination: open) {
                    Label(openTitle, systemImage: BookingPortalOpenChrome.systemImage)
                }
                .modifier(BookingPortalOpenStyle(openButtonStyle))
                .help(openHelp ?? openTitle)
            }
            if let cancel = shown.cancel {
                Link(destination: cancel) {
                    Label(BookingPortalCancelTitle.button, systemImage: BookingPortalOpenChrome.systemImage)
                }
                .buttonStyle(.bordered)
                .help(BookingPortalCancelTitle.help)
            }
        }
    }
}

private struct BookingPortalOpenStyle: ViewModifier {
    var style: BookingPortalActionBar.BookingPortalOpenButtonStyle
    func body(content: Content) -> some View {
        switch style {
        case .prominent: content.buttonStyle(.borderedProminent)
        case .bordered: content.buttonStyle(.bordered)
        }
    }
}
```

Kein Ternary `.borderedProminent : .bordered` (verschiedene Style-Typen).

`CopyLinkMenuItem` um optionalen Titel erweitern (Default bleibt `action.copy_link`):

```swift
public init(url: URL, title: String = L10n.string(.actionCopyLink)) {
```

Storno-Copy: `CopyLinkMenuItem(url: cancel, title: L10n.string(.actionCopyCancellationLink))`.

Bestehende `BookingPortalOpenButton` um Overload mit `title: BookingPortalOpenTitle.short` nicht zwingend ändern — Kontextmenüs behalten lange Titel. Neu: `BookingPortalCancelMenuButton` analog OpenButton mit `BookingPortalCancelTitle.menu`.

```swift
public struct BookingPortalCancelMenuButton: View {
    let url: URL
    @Environment(\.openURL) private var openURL

    public init(url: URL) { self.url = url }

    public var body: some View {
        Button {
            openURL(url)
        } label: {
            Label(BookingPortalCancelTitle.menu, systemImage: BookingPortalOpenChrome.systemImage)
        }
        .help(BookingPortalCancelTitle.help)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter bookingPortalCancelTitle --filter bookingPortalOpenTitle`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain Sources/ReisenSharedUI/BookingPortalOpenLink.swift \
  Tests/ReisenDomainTests/BookingPortalCancelTitleTests.swift \
  Tests/ReisenDomainTests/BookingPortalOpenTitleTests.swift
git commit -m "$(cat <<'EOF'
feat: add HIG open and cancel portal action controls

EOF
)"
```

---

### Task 5: App-Verdrahtung (Detail, Menüs, Command)

**Files:**
- Modify: `Sources/Reisen/App/BookingDetailContent.swift`
- Modify: `Sources/Reisen/App/TripDetailView.swift`
- Modify: `Sources/Reisen/App/ContentView.swift`
- Modify: `Sources/Reisen/App/BookingPortalOpenCommandState.swift`
- Modify: `Sources/Reisen/App/ReisenCommands.swift`
- Modify: `Apps/ReiseniOS/Shared/BookingDetailIOS.swift`
- Modify: `Apps/ReiseniOS/Shared/TripDetailIOS.swift`
- Modify: `Apps/ReiseniOS/Shared/OffenTab.swift`

**Interfaces:**
- Consumes: `BookingPortalActionBar`, `BookingPortalCancelMenuButton`, `SDBooking.browserURL` / neues `cancellationBrowserURL` am Model-Accessor
- Produces: sichtbare Einstiege Spec

- [ ] **Step 1: Add Model accessor + failing compile via use**

In `Sources/ReisenData/Models/ModelAccessors.swift` (neben `browserURL`):

```swift
var cancellationBrowserURL: URL? {
    BookingExternalURL.browserURL(from: cancellationUrl)
}
```

Es gibt keine XCUI in diesem Task. Evidence: der Code kompiliert und nutzt `isActionable` an jeder Spec-Stelle. Compiler: `bash ./Scripts/ci-build.sh --arch arm64` nach der Verdrahtung.

- [ ] **Step 2: Wire inspector / iOS links to ActionBar**

`BookingDetailContent` — den `if let url = booking.browserURL { BookingPortalOpenLink… }`-Block ersetzen durch ActionBar **ohne** Guard auf Open-URL:

```swift
let shown = BookingPortalActions.visible(
    open: booking.browserURL,
    cancellation: booking.cancellationBrowserURL,
    status: booking.status
)
if shown.open != nil || shown.cancel != nil {
    BookingPortalActionBar(
        openURL: booking.browserURL,
        cancellationURL: booking.cancellationBrowserURL,
        status: booking.status,
        openTitle: BookingPortalOpenTitle.short,
        openHelp: BookingPortalOpenTitle.openInBrowserHelp,
        openButtonStyle: .bordered
    )
    .contextMenu {
        if let url = shown.open { CopyLinkMenuItem(url: url) }
        if let url = shown.cancel {
            CopyLinkMenuItem(url: url, title: L10n.string(.actionCopyCancellationLink))
        }
    }
}
```

`BookingDetailIOS.bookingLinksSection`: **nicht** hinter `if let externalURL`. ActionBar immer wenn `shown` irgendetwas hat; sonst bestehender Text `bookingDetailNoBrowserLink`. iOS Open-Button: `openButtonStyle: .prominent`, `openTitle: BookingPortalOpenTitle.short`.

- [ ] **Step 3: Context menus**

An jeder bestehenden `BookingPortalOpenButton`-Stelle in `TripDetailView`, `ContentView`, `TripDetailIOS`, `OffenTab` direkt danach, nur wenn actionable:

```swift
if BookingPortalCancellation.isActionable(
    cancellation: booking.cancellationBrowserURL,
    open: booking.browserURL,
    status: booking.status
), let cancelURL = booking.cancellationBrowserURL {
    BookingPortalCancelMenuButton(url: cancelURL)
}
```

`SDBooking.status` ist bereits in `ModelAccessors.swift`.

- [ ] **Step 4: macOS Command**

`BookingPortalOpenCommandState`:

```swift
struct BookingPortalOpenCommandState {
    var url: URL?
    var cancellationURL: URL?
    var status: BookingStatus = .unknown

    var canOpen: Bool { url != nil }
    var canCancel: Bool {
        BookingPortalCancellation.isActionable(
            cancellation: cancellationURL,
            open: url,
            status: status
        )
    }
}
```

`ContentView`: FocusedValue **nicht** nur aus `selectedBookingPortalURL` (`browserURL`). Aus der selektierten `SDBooking` füllen: `url: booking.browserURL`, `cancellationURL: booking.cancellationBrowserURL`, `status: booking.status`. Cancel-only und Cancelled-Guard funktionieren sonst nicht.

`ReisenCommands` nach dem Open-Button:

```swift
Button(BookingPortalCancelTitle.menu) {
    if let url = bookingPortalOpenCommandState?.cancellationURL {
        openURL(url)
    }
}
.disabled(bookingPortalOpenCommandState?.canCancel != true)
.help(
    bookingPortalOpenCommandState?.canCancel == true
        ? BookingPortalCancelTitle.help
        : L10n.string(.bookingDetailNoBrowserLink)
)
```

- [ ] **Step 5: Compiler**

Run: `bash ./Scripts/ci-build.sh --arch arm64`
Expected: exit 0

- [ ] **Step 6: Commit**

```bash
git add Sources/Reisen Sources/ReisenData/Models Apps/ReiseniOS
git commit -m "$(cat <<'EOF'
feat: wire open and cancel portal actions in booking UI

EOF
)"
```

---

### Task 6: Traveloka Storno-URL (belegter Refund-Pfad)

**Files:**
- Modify: `Sources/ReisenTraveloka/TravelokaItineraryEntryParser.swift`
- Modify: `Tests/ReisenTravelokaTests/ParserTests.swift`
- Modify: `docs/dev/traveloka-impl-spec.md` (eine Zeile Surfaces-Tabelle: Refund-URL = persistierte Storno-URL)

**Interfaces:**
- Consumes: `TravelokaAPI.refundPresubmissionURL`, `ProviderBookingFacts.cancellationUrl`
- Produces: Catalog-Drafts mit Storno-URL ≠ `externalUrl`

- [ ] **Step 1: Write the failing assertions**

In `travelokaCatalogParsesAllProductTypes` nach dem activity-`externalUrl`-Expect:

```swift
#expect(activity.cancellationUrl?.contains("/refund/presubmission/EXPERIENCE/") == true)
#expect(activity.cancellationUrl != activity.externalUrl)
#expect(hotel.cancellationUrl?.contains("/refund/presubmission/") == true)
#expect(hotel.cancellationUrl != hotel.externalUrl)
```

Dasselbe Muster für vehicle und flight in dem Test (jeweils `cancellationUrl != externalUrl` und Pfad enthält `refund/presubmission`).

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter travelokaCatalogParsesAllProductTypes`
Expected: FAIL (`cancellationUrl` nil)

- [ ] **Step 3: Set cancellationUrl in facts()**

In `TravelokaItineraryEntryParser.facts`, neben `externalUrl`:

```swift
cancellationUrl: TravelokaAPI.refundPresubmissionURL(
    productType: product == .other
        ? (TravelokaJSON.string(entry["itineraryType"]) ?? "OTHER")
        : product.rawValue,
    bookingId: bookingId,
    itineraryId: itineraryId,
    routePrefix: routePrefix
).absoluteString
```

Denselben `productType`-Ausdruck wie für `detailURL` verwenden (keine zweite, abweichende Mapping-Regel — den bestehenden lokalen `productType`-String wiederverwenden, der schon an `TravelokaAPI.detailURL` geht).

Refund-Fetch in `mergeRefundDeadlinesIfNeeded` unverändert; URL wird **nicht** vom Fetch-Erfolg abhängig.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter travelokaCatalogParsesAllProductTypes`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenTraveloka Tests/ReisenTravelokaTests/ParserTests.swift docs/dev/traveloka-impl-spec.md
git commit -m "$(cat <<'EOF'
feat: store Traveloka refund page as cancellation URL

EOF
)"
```

---

### Task 7: Übrige Sync-Provider (Beleg oder bewusst nil)

**Files:**
- Modify: jeweilige Parser, die `ProviderBookingFacts` / Draft bauen
- Modify: jeweilige Catalog-/Parser-Tests
- Optional: Provider-`docs/dev/*-impl-spec.md` eine Zeile Storno-URL

**Interfaces:**
- Consumes: `ProviderBookingFacts.cancellationUrl`
- Produces: pro Provider ein Test: URL (nur mit Fixture-String) **oder** `#expect(draft.cancellationUrl == nil)`

- [ ] **Step 1: Fixture-Suche (kein Raten)**

Im Worktree:

```bash
rg -i 'cancel|storn|refund' Sources/ReisenCheck24 Sources/ReisenBookingCom Sources/ReisenAirbnb Sources/ReisenGetYourGuide Sources/ReisenOpodo Sources/ReisenBilligerMietwagen docs/fixtures/provider-research Tests --glob '*.{swift,json,html,md}'
```

Treffer, die eine **URL** (href, API-Feld, dokumentierter Pfad mit Buchungs-ID) sind: Extract in Facts legen + Test auf den Fixture-String.

Kein URL-Treffer: Catalog-Test `#expect(booking.cancellationUrl == nil)` am bestehenden Fixture-Draft (Feld existiert, bleibt leer).

**Verboten:** `cancellationUrl = externalUrl`, erfundene `/cancel`-Pfade, HAR ins Git.

- [ ] **Step 2: Red tests then implement per provider**

Reihenfolge: Check24, Booking.com, Airbnb, GetYourGuide, Opodo, billiger-mietwagen.de. Pro Anbieter: Assert schreiben, `swift test --filter <bestehender Catalog-Testname>` rot, dann Extract oder nil-Bestätigung.

- [ ] **Step 3: Run the provider catalog tests**

Run: die in Step 2 verwendeten Filter plus `swift test --filter travelokaCatalogParsesAllProductTypes`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add Sources Tests docs/dev
git commit -m "$(cat <<'EOF'
feat: extract or explicitly omit cancellation URLs per provider

EOF
)"
```

---

### Task 8: Manueller Editor

**Files:**
- Modify: `Sources/ReisenSharedUI/BookingEditor.swift`
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift` + `Localizable.xcstrings`
- Modify: `Tests/ReisenSharedUITests/PasteImportCreateBookingTests.swift` (Roundtrip `cancellationUrl`)

**Interfaces:**
- Consumes: `SDBooking.cancellationUrl`, `BookingEditor.normalizeOptionalString`
- Produces: Feld `cancellationUrl` auf `BookingEditorDraft`; Validate wie `externalUrl`

- [ ] **Step 1: Failing roundtrip**

In `PasteImportCreateBookingTests.swift` nach `createBooking`: gesetztes `draft.cancellationUrl = "https://example.com/cancel"` und `#expect` auf persistiertes `SDBooking.cancellationUrl`. Zusätzlich `fromExisting` roundtrip.

Neuer Key `editor.cancellation_url_optional` = „Storno-URL (optional)“ / „Cancellation URL (optional)“.

- [ ] **Step 2: Implement**

`BookingEditorDraft.cancellationUrl: String` (leer default). `fromExisting`: `booking.cancellationUrl ?? ""`. `createDefault`: `""`.

`validate()`: gleicher URL-Check wie `externalUrl`.

`apply(to:)` und `createBooking`: `booking.cancellationUrl = Self.normalizeOptionalString(working.cancellationUrl)`.

UI: `TextField(L10n.string(.editorCancellationUrlOptional), text: $draft.cancellationUrl)` direkt unter dem bestehenden URL-Feld, gleiche `.textContentType(.URL)` / iOS Keyboard-Modifier.

- [ ] **Step 3: Compiler + gezielte Tests**

Run: `swift test --filter BookingEditor` (falls Treffer); sonst `bash ./Scripts/ci-build.sh --arch arm64`
Expected: PASS / exit 0

- [ ] **Step 4: Commit**

```bash
git add Sources/ReisenSharedUI/BookingEditor.swift Sources/ReisenDomain/Localization Sources/ReisenDomain/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
feat: allow optional cancellation URL in booking editor

EOF
)"
```

---

### Task 9: Doku-Matrix

**Files:**
- Modify: `docs/dev/booking-portal-open.md`

**Interfaces:** none (Docs)

- [ ] **Step 1: Extend the matrix**

Neuen Abschnitt **Buchungs-Storno** mit Tabelle Provider × Storno-URL-Form × Button (ja/nein). Traveloka-Zeile konkret (`refund/presubmission`). Andere Zeilen: „unbelegt in Fixtures → kein Button“ oder der tatsächlich extrahierte Pfad aus Task 7. Verweis auf `BookingPortalCancellation.isActionable`.

Kein F15. Open-Abschnitt unverändert lassen außer einem Satz „Storno ist ein zweiter HTTPS-Pfad, nicht `externalUrl`.“

- [ ] **Step 2: Commit**

```bash
git add docs/dev/booking-portal-open.md
git commit -m "$(cat <<'EOF'
docs: document cancellation portal URLs next to booking open

EOF
)"
```

---

## Spec coverage

| Spec | Task |
|------|------|
| Domain-Feld + Filter | 1 |
| Draft/Enrich/Upsert | 2 |
| SwiftData | 3 |
| HIG Buttons + L10n | 4–5 |
| Traveloka Refund-URL | 6 |
| Alle übrigen Provider | 7 |
| Editor | 8 |
| Docs + open_gaps sichtbar | 7, 9 |
| Kein Paste-Import | bewusst kein Task |
| Kein in-App-Storno / kein destructive | 4–5 |

## Self-review

- Kein TBD in Tasks; Provider ohne Beleg haben ein explizites nil-Assert.
- Namen: `cancellationUrl` durchgängig, nicht `cancelUrl`/`stornoUrl`.
- `BookingPortalCancellation.isActionable` Signatur in Task 1 = Nutzung in 4–5.
