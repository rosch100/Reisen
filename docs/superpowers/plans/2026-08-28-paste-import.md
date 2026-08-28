# Paste-Import (F06) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nutzer fügt Text/Bild/PDF ein, die App extrahiert Buchungskandidaten (PCC wenn möglich, sonst On-Device), der Nutzer wählt und prüft im bestehenden `BookingEditor`, erst dann wird gespeichert (Neu als `manual` oder Ergänzen einer bestehenden Buchung).

**Architecture:** Domain besitzt Quelle, Filter, Match (über `SyncBookingMatchIndex`) und Merge. Neues Target `ReisenPasteImport` spricht Foundation Models und mappt `@Generable` → Domain. SharedUI/Apps orchestrieren Review; ReisenData bleibt auf `BookingEditorDraft.createBooking` / `apply`.

**Tech Stack:** Swift 6.3, Swift Testing, Foundation Models (`LanguageModelSession`, `PrivateCloudComputeLanguageModel`, `SystemLanguageModel`), PDFKit, SwiftUI, XcodeGen (`project.yml`), App Group für iOS-Share.

**Spec:** [`docs/superpowers/specs/2026-08-28-paste-import-design.md`](../specs/2026-08-28-paste-import-design.md)

## Global Constraints

- Schichten: Domain ohne FoundationModels/PDFKit/UIKit; Adapter in `ReisenPasteImport`; Speichern nur über bestehenden Editor.
- Keine stillen Fallbacks: unsichere Felder weglassen; PCC-Fehler nicht On-Device; kein Dummy-Kandidat; kein `createDefault`-Hotel-Minuten für Paste-Create.
- Match: `SyncBookingMatchIndex` / `SyncBookingMatchLookup`-Indexe; Fingerprint nur wenn `endAtIsPlaceholder == false`; Mehrdeutigkeit → Neu + Hinweis, keine stille Wahl.
- Merge: nur Lücken (`nil`/leer); `provider`, `externalUrl`, `lastSyncedAt`, `tripID` unverändert.
- Modell: PCC wenn verfügbar, sonst On-Device, sonst disabled mit Begründung. Kein Drittanbieter-LLM in v1.
- Tests: `swift test --filter <Name>`; CI-Parität später `bash ./Scripts/ci-test.sh`. Kein Live-Modell in CI (Port mocken).
- iOS-Projekt nur über `bash ./Scripts/generate-ios-project.sh`. Default-Simulator: `iPad Pro 13-inch (M5)`.
- L10n: jeder neue `L10nKey` in `Localizable.xcstrings` de+en; `L10nTests` müssen grün bleiben.
- ⌘V bleibt System-Paste.

---

## File map

| Datei | Verantwortung |
|---|---|
| `Sources/ReisenDomain/PasteImport/PasteImportSource.swift` | Quelle Text/Bild/PDF + Leer-Validierung |
| `Sources/ReisenDomain/PasteImport/PasteImportModelKind.swift` | `privateCloudCompute` / `onDevice` / `unavailable` |
| `Sources/ReisenDomain/PasteImport/PasteImportModelResolver.swift` | Reine Wahl aus Availability-Flags |
| `Sources/ReisenDomain/PasteImport/PasteImportExtraction.swift` | Rohextrakt (optionale Felder) |
| `Sources/ReisenDomain/PasteImport/PasteImportFilter.swift` | Typ+`startAt` Pflicht; `endAt`-Platzhalter |
| `Sources/ReisenDomain/PasteImport/PasteImportDraft.swift` | Gefilterter Draft + `endAtIsPlaceholder` |
| `Sources/ReisenDomain/PasteImport/PasteImportMatching.swift` | Unique / none / ambiguous über bestehenden Index |
| `Sources/ReisenDomain/PasteImport/PasteImportMerger.swift` | Lücken füllen auf `Booking` |
| `Sources/ReisenDomain/PasteImport/PasteImportExtracting.swift` | Port |
| `Sources/ReisenDomain/PasteImport/PasteImportPipeline.swift` | Filter + Match → `PasteImportCandidate` |
| `Sources/ReisenPasteImport/*` | Availability, Session, `@Generable`, PDF/Bild, Mapping |
| `Sources/ReisenSharedUI/PasteImport/*` | Aktion, Liste, Editor-Prefill |
| `Sources/Reisen/App/ReisenCommands.swift` | Menü ⌘⇧V |
| `Apps/ReiseniOS/**` + `project.yml` | iOS-Einstieg + Share-Extension |
| `docs/legal/privacy.html`, `docs/legal/en/privacy.html` | PCC + ephemerer Paste-Import |

---

### Task 1: Quelle validieren

**Files:**
- Create: `Sources/ReisenDomain/PasteImport/PasteImportSource.swift`
- Test: `Tests/ReisenDomainTests/PasteImportSourceTests.swift`

**Interfaces:**
- Consumes: nichts
- Produces: `PasteImportSource` mit `validate() throws`

- [ ] **Step 1: Failing test**

```swift
import Foundation
import Testing
import ReisenDomain

@Test func pasteImportSource_rejectsEmptyText() {
    #expect(throws: PasteImportSourceError.empty) {
        try PasteImportSource.text("  \n").validated()
    }
}

@Test func pasteImportSource_acceptsNonEmptyText() throws {
    let source = try PasteImportSource.text("ICE 123 Berlin").validated()
    #expect(source == .text("ICE 123 Berlin"))
}

@Test func pasteImportSource_rejectsEmptyData() {
    #expect(throws: PasteImportSourceError.empty) {
        try PasteImportSource.image(Data()).validated()
    }
    #expect(throws: PasteImportSourceError.empty) {
        try PasteImportSource.pdf(Data()).validated()
    }
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter PasteImportSource`
Expected: FAIL (`PasteImportSource` / `PasteImportSourceError` missing)

- [ ] **Step 3: Minimal implementation**

```swift
import Foundation

public enum PasteImportSourceError: Error, Equatable, Sendable {
    case empty
}

public enum PasteImportSource: Equatable, Sendable {
    case text(String)
    case image(Data)
    case pdf(Data)

    public func validated() throws -> PasteImportSource {
        switch self {
        case .text(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw PasteImportSourceError.empty }
            return .text(trimmed)
        case .image(let data), .pdf(let data):
            guard !data.isEmpty else { throw PasteImportSourceError.empty }
            return self
        }
    }
}
```

- [ ] **Step 4: Run GREEN**

Run: `swift test --filter PasteImportSource`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/PasteImport/PasteImportSource.swift Tests/ReisenDomainTests/PasteImportSourceTests.swift
git commit -m "feat: validate paste-import source payload"
```

---

### Task 2: Filter Typ + startAt, endAt-Platzhalter

**Files:**
- Create: `Sources/ReisenDomain/PasteImport/PasteImportExtraction.swift`
- Create: `Sources/ReisenDomain/PasteImport/PasteImportDraft.swift`
- Create: `Sources/ReisenDomain/PasteImport/PasteImportFilter.swift`
- Test: `Tests/ReisenDomainTests/PasteImportFilterTests.swift`

**Interfaces:**
- Consumes: `BookingType`, `ProviderBookingDraft`-Felder als Optionals
- Produces: `PasteImportFilter.apply(_:now:) -> [PasteImportDraft]`

`PasteImportExtraction` (alle Felder optional außer dass mindestens etwas kommen kann):

```swift
public struct PasteImportExtraction: Equatable, Sendable {
    public var bookingType: BookingType?
    public var startAt: Date?
    public var endAt: Date?
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var operatorName: String?
    public var status: BookingStatus?
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var hotelOffsetSeconds: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var passengers: [BookingPassenger]
    public var guestHints: [BookingGuestHint]
    public var rateDetails: BookingRateDetails?
    public var deadlines: [CancellationDeadline]
}
```

`PasteImportDraft`:

```swift
public struct PasteImportDraft: Equatable, Sendable {
    public var bookingType: BookingType
    public var startAt: Date
    public var endAt: Date
    public var endAtIsPlaceholder: Bool
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var operatorName: String?
    public var status: BookingStatus
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var hotelOffsetSeconds: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var passengers: [BookingPassenger]
    public var guestHints: [BookingGuestHint]
    public var rateDetails: BookingRateDetails?
    public var deadlines: [CancellationDeadline]

    public func asProviderDraft() -> ProviderBookingDraft {
        ProviderBookingDraft(
            provider: .manual,
            bookingType: bookingType,
            title: title,
            confirmationCode: confirmationCode,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: locationFrom,
            locationTo: locationTo,
            locationFromAddress: locationFromAddress,
            locationToAddress: locationToAddress,
            operatorName: operatorName,
            status: status,
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: hotelOffsetSeconds,
            hotelCheckInMinutes: hotelCheckInMinutes,
            hotelCheckOutMinutes: hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: flightArrivalOffsetSeconds,
            passengers: passengers,
            guestHints: guestHints
        )
    }
}
```

- [ ] **Step 1: Failing tests**

```swift
@Test func pasteImportFilter_dropsExtractionWithoutTypeOrStart() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let noType = PasteImportExtraction(startAt: start, title: "ICE")
    let noStart = PasteImportExtraction(bookingType: .train, title: "ICE")
    #expect(PasteImportFilter.apply([noType, noStart]).isEmpty)
}

@Test func pasteImportFilter_keepsTypeAndStart_placeholdersMissingEnd() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let extraction = PasteImportExtraction(bookingType: .train, startAt: start, title: "ICE 123")
    let drafts = PasteImportFilter.apply([extraction])
    #expect(drafts.count == 1)
    #expect(drafts[0].bookingType == .train)
    #expect(drafts[0].startAt == start)
    #expect(drafts[0].endAt == start)
    #expect(drafts[0].endAtIsPlaceholder == true)
    #expect(drafts[0].title == "ICE 123")
}

@Test func pasteImportFilter_keepsExplicitEnd() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(7200)
    let extraction = PasteImportExtraction(bookingType: .flight, startAt: start, endAt: end)
    let drafts = PasteImportFilter.apply([extraction])
    #expect(drafts[0].endAt == end)
    #expect(drafts[0].endAtIsPlaceholder == false)
}
```

`PasteImportExtraction` braucht einen Memberwise-Init mit Defaults `nil` / `[]`.

- [ ] **Step 2: Run RED** — `swift test --filter PasteImportFilter` → FAIL
- [ ] **Step 3: Implement** `PasteImportFilter.apply`: skip wenn `bookingType` oder `startAt` nil; `endAtIsPlaceholder = (endAt == nil)`; `endAt = extraction.endAt ?? startAt`; `status = extraction.status ?? .unknown`; Strings die nach Trim leer sind → `nil`.
- [ ] **Step 4: GREEN** — `swift test --filter PasteImportFilter`
- [ ] **Step 5: Commit** `feat: filter paste-import extractions to typed drafts`

---

### Task 3: Match unique / none / ambiguous

**Files:**
- Create: `Sources/ReisenDomain/PasteImport/PasteImportMatching.swift`
- Test: `Tests/ReisenDomainTests/PasteImportMatchingTests.swift`

**Interfaces:**
- Consumes: `PasteImportDraft`, `[Booking]`, `SyncBookingMatchIndex`, `BookingTimeNormalizer`
- Produces: `PasteImportMatch: Equatable` = `unique(Booking)` | `none` | `ambiguous`

Nicht `SyncBookingMatchLookup.match` allein nutzen: die Funktion macht unique und none ununterscheidbar. Dieselben Indexe (`byURL`, `byConfirmationCode`, `byDateFingerprint`) lesen. Reihenfolge: URL (wenn `externalUrl` nicht leer), dann Code, dann Fingerprint nur wenn `!endAtIsPlaceholder`.

```swift
public enum PasteImportMatch: Equatable, Sendable {
    case unique(Booking)
    case none
    case ambiguous
}

public enum PasteImportMatching {
    public static func match(
        draft: PasteImportDraft,
        index: SyncBookingMatchIndex,
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> PasteImportMatch
}
```

Helper: `uniqueOrAmbiguous(_ dict: [UUID: Booking]) -> PasteImportMatch?` — count 1 → unique, count > 1 → ambiguous, 0 → nil (weiter).

- [ ] **Step 1: Tests**

```swift
private let start = Date(timeIntervalSince1970: 1_800_000_000)
private let end = start.addingTimeInterval(86_400)
private let calendar = Calendar(identifier: .gregorian)

private func hotel(id: UUID = UUID(), code: String?, provider: ProviderID = .check24) -> Booking {
    Booking(
        id: id,
        provider: provider,
        bookingType: .hotel,
        confirmationCode: code,
        startAt: start,
        endAt: end
    )
}

@Test func pasteImportMatching_uniqueConfirmationCode() {
    let existing = hotel(code: "ABC123")
    let index = SyncBookingMatchIndex(existing: [existing], calendar: calendar)
    var draft = PasteImportFilter.apply([
        PasteImportExtraction(bookingType: .hotel, startAt: start, endAt: end, confirmationCode: "ABC123")
    ])[0]
    let result = PasteImportMatching.match(
        draft: draft,
        index: index,
        calendar: calendar,
        normalizer: BookingTimeNormalizer()
    )
    #expect(result == .unique(existing))
}

@Test func pasteImportMatching_ambiguousConfirmationCode() {
    let a = hotel(code: "ABC123")
    let b = hotel(code: "ABC123")
    let index = SyncBookingMatchIndex(existing: [a, b], calendar: calendar)
    let draft = PasteImportFilter.apply([
        PasteImportExtraction(bookingType: .hotel, startAt: start, endAt: end, confirmationCode: "ABC123")
    ])[0]
    let result = PasteImportMatching.match(
        draft: draft,
        index: index,
        calendar: calendar,
        normalizer: BookingTimeNormalizer()
    )
    #expect(result == .ambiguous)
}

@Test func pasteImportMatching_skipsFingerprintWhenEndPlaceholder() {
    let existing = hotel(code: nil)
    let index = SyncBookingMatchIndex(existing: [existing], calendar: calendar)
    let draft = PasteImportFilter.apply([
        PasteImportExtraction(bookingType: .hotel, startAt: start, title: "Hotel")
    ])[0]
    #expect(draft.endAtIsPlaceholder)
    let result = PasteImportMatching.match(
        draft: draft,
        index: index,
        calendar: calendar,
        normalizer: BookingTimeNormalizer()
    )
    #expect(result == .none)
}

@Test func pasteImportMatching_fingerprintWhenEndKnown() {
    let existing = hotel(code: nil)
    let index = SyncBookingMatchIndex(existing: [existing], calendar: calendar)
    let draft = PasteImportFilter.apply([
        PasteImportExtraction(bookingType: .hotel, startAt: start, endAt: end)
    ])[0]
    let result = PasteImportMatching.match(
        draft: draft,
        index: index,
        calendar: calendar,
        normalizer: BookingTimeNormalizer()
    )
    #expect(result == .unique(existing))
}
```

Fix `var draft` in first test (unused mutability) — `let draft`.

- [ ] **Step 2: RED** — `swift test --filter PasteImportMatching`
- [ ] **Step 3: Implement** `PasteImportMatching` wie oben. URL-Zweig: wenn `draft.externalUrl` nicht nil/leer und `index.byURL[url]` gesetzt → `.unique`. `byURL` ist 1:1; Kollisionen gibt der Index nicht als Array — dann unique. Code-Zweig über `index.byConfirmationCode`. Fingerprint: `SyncBookingDateFingerprint.key(for: draft.asProviderDraft(), calendar:calendar, normalizer:normalizer)` dann `index.byDateFingerprint[key]`.
- [ ] **Step 4: GREEN**
- [ ] **Step 5: Commit** `feat: match paste-import drafts to existing bookings`

---

### Task 4: Merge nur Lücken

**Files:**
- Create: `Sources/ReisenDomain/PasteImport/PasteImportMerger.swift`
- Test: `Tests/ReisenDomainTests/PasteImportMergerTests.swift`

**Interfaces:**
- Consumes: `Booking`, `PasteImportDraft`
- Produces: `Booking` (gleiche `id`, `provider`, `externalUrl`, `lastSyncedAt`, `tripID`; `startAt`/`endAt`/`bookingType` unverändert)

Leer = `nil` oder (bei String) trim empty. Paste-Wert nur setzen wenn Ziel leer.

```swift
public enum PasteImportMerger {
    public static func fillingGaps(on booking: Booking, from draft: PasteImportDraft) -> Booking
}
```

- [ ] **Step 1: Tests**

```swift
@Test func pasteImportMerger_fillsNilConfirmationKeepsProviderAndTrip() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var existing = Booking(
        provider: .check24,
        bookingType: .hotel,
        title: "Hotel Berlin",
        startAt: start,
        endAt: start.addingTimeInterval(86_400),
        lastSyncedAt: start,
        tripID: UUID()
    )
    existing.externalUrl = "https://check24.example/x"
    let draft = PasteImportFilter.apply([
        PasteImportExtraction(
            bookingType: .train,
            startAt: start.addingTimeInterval(10),
            confirmationCode: "XYZ",
            title: "Ignored Title"
        )
    ])[0]
    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)
    #expect(merged.provider == .check24)
    #expect(merged.bookingType == .hotel)
    #expect(merged.title == "Hotel Berlin")
    #expect(merged.confirmationCode == "XYZ")
    #expect(merged.externalUrl == "https://check24.example/x")
    #expect(merged.lastSyncedAt == start)
    #expect(merged.tripID == existing.tripID)
    #expect(merged.startAt == existing.startAt)
}

@Test func pasteImportMerger_doesNotOverwriteExistingCode() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let existing = Booking(
        provider: .opodo,
        bookingType: .flight,
        confirmationCode: "KEEP",
        startAt: start,
        endAt: start
    )
    let draft = PasteImportFilter.apply([
        PasteImportExtraction(bookingType: .flight, startAt: start, confirmationCode: "NEW")
    ])[0]
    let merged = PasteImportMerger.fillingGaps(on: existing, from: draft)
    #expect(merged.confirmationCode == "KEEP")
}
```

- [ ] **Step 2: RED** — `swift test --filter PasteImportMerger`
- [ ] **Step 3: Implement** Füllen für: `title`, `confirmationCode`, `locationFrom/To` + Adressen, `operatorName`, `hotelCheckIn/OutMinutes`, Offsets, `rateDetails` wenn `booking.rateDetails == nil`, `passengers`/`guestHints`/`deadlines` nur wenn das bestehende Array leer ist. Nie `provider`, `externalUrl`, `lastSyncedAt`, `tripID`, `id`, `bookingType`, `startAt`, `endAt`.
- [ ] **Step 4: GREEN**
- [ ] **Step 5: Commit** `feat: fill only empty booking fields from paste`

---

### Task 5: Resolver + Pipeline + Port

**Files:**
- Create: `Sources/ReisenDomain/PasteImport/PasteImportModelKind.swift`
- Create: `Sources/ReisenDomain/PasteImport/PasteImportModelAvailability.swift`
- Create: `Sources/ReisenDomain/PasteImport/PasteImportModelResolver.swift`
- Create: `Sources/ReisenDomain/PasteImport/PasteImportExtracting.swift`
- Create: `Sources/ReisenDomain/PasteImport/PasteImportCandidate.swift`
- Create: `Sources/ReisenDomain/PasteImport/PasteImportPipeline.swift`
- Test: `Tests/ReisenDomainTests/PasteImportResolverTests.swift`
- Test: `Tests/ReisenDomainTests/PasteImportPipelineTests.swift`

**Interfaces:**

```swift
public enum PasteImportModelKind: String, Equatable, Sendable {
    case privateCloudCompute
    case onDevice
    case unavailable
}

public struct PasteImportModelAvailability: Equatable, Sendable {
    public var privateCloudCompute: Bool
    public var onDevice: Bool
}

public enum PasteImportModelResolver {
    public static func resolve(_ availability: PasteImportModelAvailability) -> PasteImportModelKind {
        if availability.privateCloudCompute { return .privateCloudCompute }
        if availability.onDevice { return .onDevice }
        return .unavailable
    }
}

public protocol PasteImportExtracting: Sendable {
    func extract(from source: PasteImportSource) async throws -> [PasteImportExtraction]
}

public struct PasteImportCandidate: Equatable, Sendable {
    public var draft: PasteImportDraft
    public var match: PasteImportMatch
    public var isEnrichment: Bool { if case .unique = match { return true }; return false }
    public var showsAmbiguousHint: Bool { match == .ambiguous }
}

public enum PasteImportPipeline {
    public static func candidates(
        from extractions: [PasteImportExtraction],
        existing: [Booking],
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> [PasteImportCandidate]
}
```

Pipeline: `Filter.apply` → Index aus `existing` → je Draft `PasteImportMatching.match`.

- [ ] **Step 1: Tests**

```swift
@Test func resolver_prefersPCC() {
    #expect(PasteImportModelResolver.resolve(.init(privateCloudCompute: true, onDevice: true)) == .privateCloudCompute)
}

@Test func resolver_onDeviceWhenPCCMissing() {
    #expect(PasteImportModelResolver.resolve(.init(privateCloudCompute: false, onDevice: true)) == .onDevice)
}

@Test func resolver_unavailableWhenNeither() {
    #expect(PasteImportModelResolver.resolve(.init(privateCloudCompute: false, onDevice: false)) == .unavailable)
}

@Test func pipeline_marksAmbiguousAsMatchCase() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let end = start.addingTimeInterval(86_400)
    let a = Booking(provider: .check24, bookingType: .hotel, confirmationCode: "X", startAt: start, endAt: end)
    let b = Booking(provider: .opodo, bookingType: .hotel, confirmationCode: "X", startAt: start, endAt: end)
    let candidates = PasteImportPipeline.candidates(
        from: [PasteImportExtraction(bookingType: .hotel, startAt: start, endAt: end, confirmationCode: "X")],
        existing: [a, b],
        calendar: Calendar(identifier: .gregorian),
        normalizer: BookingTimeNormalizer()
    )
    #expect(candidates.count == 1)
    #expect(candidates[0].match == .ambiguous)
}
```

Kein Test, der bei PCC-false automatisch On-Device „als Fallback nach Fehler“ wählt — Resolver sieht nur Availability, nie einen Fehler.

- [ ] **Step 2–4:** RED / implement / GREEN (`swift test --filter PasteImportResolver`; `swift test --filter PasteImportPipeline`)
- [ ] **Step 5: Commit** `feat: resolve paste-import model and build candidates`

---

### Task 6: L10n-Keys

**Files:**
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift` (nach `menuAddBooking`)
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Test: bestehend `Tests/ReisenDomainTests/L10nTests.swift` (keine neue Datei)

**Interfaces:**
- Produces: Keys (rawValues exakt):

| Key | de | en |
|---|---|---|
| `menu.paste_booking` | Buchung einfügen… | Paste Booking… |
| `paste_import.unavailable` | Apple Intelligence ist auf diesem Gerät nicht verfügbar. | Apple Intelligence is not available on this device. |
| `paste_import.model_on_device` | On-Device | On-Device |
| `paste_import.model_pcc` | Private Cloud Compute | Private Cloud Compute |
| `paste_import.pcc_confirm_title` | An Private Cloud Compute senden? | Send to Private Cloud Compute? |
| `paste_import.pcc_confirm_message` | Der eingefügte Buchungstext verlässt das Gerät und wird von Apple Private Cloud Compute verarbeitet. | The pasted booking content leaves this device and is processed by Apple Private Cloud Compute. |
| `paste_import.pcc_confirm_ok` | Senden | Send |
| `paste_import.progress` | Buchungen erkennen… | Detecting bookings… |
| `paste_import.empty` | Keine Buchung erkannt. Typ und Beginn müssen sicher sein. | No booking detected. Type and start must be certain. |
| `paste_import.badge_new` | Neu | New |
| `paste_import.badge_enrich` | Ergänzen | Update |
| `paste_import.ambiguous_hint` | Keine eindeutige Zuordnung | No unique match |
| `paste_import.error_title` | Einfügen fehlgeschlagen | Paste failed |
| `paste_import.error_model` | Das Modell hat nicht geantwortet. | The model did not respond. |
| `paste_import.error_handoff` | Die geteilte Datei konnte nicht übernommen werden. | The shared file could not be imported. |
| `paste_import.candidates_title` | Erkannte Buchungen | Detected bookings |
| `paste_import.continue` | Weiter | Continue |
| `paste_import.share_display_name` | In Reisen öffnen | Open in Reisen |

xcstrings-Eintrag analog `menu.add_booking` (state `translated`, de+en).

- [ ] **Step 1:** Keys + xcstrings hinzufügen
- [ ] **Step 2:** `swift test --filter l10n_allKeys` → PASS
- [ ] **Step 3: Commit** `feat: add paste-import localization keys`

---

### Task 7: Target `ReisenPasteImport` + Mapper (ohne Live-Modell)

**Files:**
- Modify: `Package.swift` — library product + target + `ReisenPasteImportTests`; `ReisenSharedUI` hängt später dran (Task 9). In diesem Task nur Domain-abhängiges Target.
- Create: `Sources/ReisenPasteImport/PasteImportGenerableDTO.swift`
- Create: `Sources/ReisenPasteImport/PasteImportGenerableMapper.swift`
- Test: `Tests/ReisenPasteImportTests/PasteImportGenerableMapperTests.swift`

**Interfaces:**
- Consumes: `PasteImportExtraction`
- Produces: Mapper von DTO → `[PasteImportExtraction]`; Neu-Anlagen später `provider == .manual` über `asProviderDraft()`

`@Generable` darf FoundationModels brauchen. Damit CI ohne Modell kompiliert: DTO ist ein **reines** `Codable`-Struct im Adapter, das dieselbe Form hat wie das Generable-Schema. Die Session-Schicht (Task 8) annotiert dasselbe Struct mit `@Generable` **oder** ein Wrapper-Struct `PasteImportGenerablePayload: Generable` mit identischen Feldern, Mapper liest das Codable-Double.

Konkretes DTO (ohne FoundationModels-Import in dieser Datei):

```swift
public struct PasteImportPayloadDTO: Codable, Equatable, Sendable {
    public var bookings: [PasteImportBookingDTO]
}

public struct PasteImportBookingDTO: Codable, Equatable, Sendable {
    public var bookingType: String?
    public var startAtISO8601: String?
    public var endAtISO8601: String?
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var locationFrom: String?
    public var locationTo: String?
}
```

Mapper: unbekannter `bookingType`-String → Extraction mit `bookingType == nil` (Filter droppt). Kein Map auf `.other` bei unbekanntem String. ISO8601 über `ISO8601DateFormatter`. Leere Strings → nil.

- [ ] **Step 1: Test**

```swift
@Test func mapper_unknownTypeBecomesNilNotOther() throws {
    let dto = PasteImportBookingDTO(bookingType: "spaceship", startAtISO8601: "2026-08-28T10:00:00Z", title: "X")
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
    #expect(extraction.bookingType == nil)
    #expect(extraction.startAt != nil)
}

@Test func mapper_trainAndStart_roundTripFilterKeepsManualProvider() throws {
    let dto = PasteImportBookingDTO(bookingType: "train", startAtISO8601: "2026-08-28T10:00:00Z", title: "ICE 123")
    let extraction = try PasteImportGenerableMapper.extraction(from: dto)
    let draft = PasteImportFilter.apply([extraction])[0]
    #expect(draft.asProviderDraft().provider == .manual)
    #expect(draft.bookingType == .train)
}
```

- [ ] **Step 2:** `Package.swift` Target:

```swift
.library(name: "ReisenPasteImport", targets: ["ReisenPasteImport"]),
.target(
    name: "ReisenPasteImport",
    dependencies: ["ReisenDomain"],
    path: "Sources/ReisenPasteImport",
    swiftSettings: [.enableUpcomingFeature("ApproachableConcurrency")]
),
.testTarget(
    name: "ReisenPasteImportTests",
    dependencies: ["ReisenPasteImport", "ReisenDomain"],
    path: "Tests/ReisenPasteImportTests",
    swiftSettings: [.enableUpcomingFeature("ApproachableConcurrency")]
),
```

Linker PDFKit erst in Task 8.

- [ ] **Step 3–4:** RED/GREEN `swift test --filter PasteImportGenerableMapper`
- [ ] **Step 5: Commit** `feat: add paste-import DTO mapper target`

---

### Task 8: Availability + Extractor (Foundation Models, PDF)

**Files:**
- Create: `Sources/ReisenPasteImport/FoundationModelsPasteImportAvailability.swift`
- Create: `Sources/ReisenPasteImport/FoundationModelsPasteImportExtractor.swift`
- Create: `Sources/ReisenPasteImport/PasteImportPDFText.swift`
- Modify: `Package.swift` Target `ReisenPasteImport`: `linkerSettings: [.linkedFramework("PDFKit")]`
- Test: `Tests/ReisenPasteImportTests/PasteImportPDFTextTests.swift`
- Test: `Tests/ReisenPasteImportTests/FoundationModelsPasteImportAvailabilityTests.swift` nur wenn Availability ohne Hardware assertbar ist — sonst Availability hinter `PasteImportAvailabilityReading` Port im Adapter, Test mit Fake.

**Interfaces:**

```swift
public protocol PasteImportAvailabilityReading: Sendable {
    func availability() -> PasteImportModelAvailability
}

public struct FoundationModelsPasteImportAvailability: PasteImportAvailabilityReading {
    public init() {}
    public func availability() -> PasteImportModelAvailability
}

public struct FoundationModelsPasteImportExtractor: PasteImportExtracting {
    public init(kind: PasteImportModelKind)
    public func extract(from source: PasteImportSource) async throws -> [PasteImportExtraction]
}
```

`availability()`: PCC `true` nur wenn `PrivateCloudComputeLanguageModel()` (bzw. aktuelle SDK-API) available; On-Device nur wenn `SystemLanguageModel.default` available. Exakte API aus dem lokalen SDK übernehmen (WWDC26: `model.availability == .available`). Kein `true` raten.

`extract`: wenn `kind == .unavailable` → throw `PasteImportAdapterError.unavailable` (UI darf extract dann nicht aufrufen). Sonst `LanguageModelSession` mit genau dem Modell zu `kind` (PCC-Instanz oder `SystemLanguageModel.default`). Structured Output: `@Generable`-Zwilling `PasteImportGenerablePayload` mit denselben Feldern wie `PasteImportPayloadDTO`, danach `PasteImportGenerableMapper`. Prompt: nur sichere Felder; unsichere weglassen.

Bild: `Attachment` in den Prompt (SDK WWDC26). Fehlt die API im lokalen SDK: Task **BLOCKED** melden — kein OCR-Workaround.

PDF: `PasteImportPDFText.string(from: Data) throws` — 0 Seiten oder leerer Text → `PasteImportAdapterError.unreadableSource`; sonst Text in den Prompt.

`PasteImportPDFText` mit einem minimalen PDF-Fixture in `Tests/ReisenPasteImportTests/Fixtures/hello.pdf` (ein Seite, Text „ICE 123“) testen.

Extractor-Fehler nicht fangen und On-Device retryen.

- [ ] **Step 1:** PDF-Test RED/GREEN unabhängig vom Modell
- [ ] **Step 2:** Availability-Reader + Extractor implementieren; Compiler `swift build --target ReisenPasteImport`
- [ ] **Step 3:** Commit `feat: extract paste-import bookings via Foundation Models`

---

### Task 9: SharedUI Prefill + Kandidatenliste

**Files:**
- Modify: `Package.swift` `ReisenSharedUI` dependencies: `"ReisenPasteImport"`
- Create: `Sources/ReisenSharedUI/PasteImport/PasteImportEditorPrefill.swift`
- Create: `Sources/ReisenSharedUI/PasteImport/PasteImportCandidateList.swift`
- Create: `Sources/ReisenSharedUI/PasteImport/PasteImportActionControl.swift`
- Test: `Tests/ReisenSharedUITests/PasteImportEditorPrefillTests.swift`
- Test: `Tests/ReisenSharedUITests/PasteImportCandidatePresentationTests.swift`

**Interfaces:**

```swift
public enum PasteImportEditorPrefill {
    public static func draft(
        for candidate: PasteImportCandidate,
        existing: SDBooking?,
        tripStartDate: Date
    ) -> BookingEditorDraft
}
```

- Neu: `BookingEditorDraft` aus `PasteImportDraft` **ohne** `createDefault`. `title` darf leer sein (Editor-Validierung blockt Speichern). `hotelCheckInMinutesText` leer wenn Draft nil. `provider = .manual`. `startAt`/`endAt` aus Draft.
- Ergänzen: `fromExisting(existing)` danach Domain-Merge: `PasteImportMerger.fillingGaps` auf `DomainMapper.booking(from: existing)` nicht zwingend — Prefill arbeitet auf `BookingEditorDraft`: für jedes String-Feld, wenn existing-Text leer und Draft gesetzt → setzen. `bookingID` bleibt. `provider` bleibt der der SDBooking.

Presentation: `PasteImportCandidate.isEnrichment: Bool { if case .unique = match { true } else { false } }`, `showsAmbiguousHint: Bool { match == .ambiguous }`.

`PasteImportActionControl`: `kind: PasteImportModelKind`, disabled wenn `.unavailable`, Accessibility-Label = Menüstring + Begründung.

- [ ] **Step 1: Tests**

```swift
@Test func prefill_newDoesNotUseHotelMinuteDefaults() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let draft = PasteImportFilter.apply([
        PasteImportExtraction(bookingType: .hotel, startAt: start, title: "Hotel")
    ])[0]
    let candidate = PasteImportCandidate(draft: draft, match: .none)
    let editor = PasteImportEditorPrefill.draft(
        for: candidate,
        existing: nil,
        tripStartDate: start
    )
    #expect(editor.hotelCheckInMinutesText.isEmpty)
    #expect(editor.hotelCheckOutMinutesText.isEmpty)
    #expect(editor.provider == .manual)
    #expect(editor.bookingType == .hotel)
}

@Test func candidate_ambiguousShowsHintNotEnrichment() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let draft = PasteImportFilter.apply([
        PasteImportExtraction(bookingType: .hotel, startAt: start, endAt: start)
    ])[0]
    let candidate = PasteImportCandidate(draft: draft, match: .ambiguous)
    #expect(candidate.isEnrichment == false)
    #expect(candidate.showsAmbiguousHint)
}
```

`isEnrichment` / `showsAmbiguousHint` kommen aus Task 5 (`PasteImportCandidate`).

- [ ] **Step 2–4:** RED/GREEN `swift test --filter PasteImportEditorPrefill`; `swift test --filter candidate_ambiguous`
- [ ] **Step 5: Commit** `feat: prefill booking editor from paste candidates`

Liste-UI (`PasteImportCandidateList`): SwiftUI `List` mit Toggle, Symbol `booking.bookingType.systemImageName` (bestehendes SharedUI), Badges über L10n, Standard alle `true`. Kein Snapshot-Test nötig; Presentation-Tests reichen.

---

### Task 10: macOS-Einstieg und Flow

**Files:**
- Modify: `Sources/Reisen/App/ReisenCommands.swift` — Button nach `menuAddBooking`, Shortcut `v` + `[.command, .shift]`
- Modify: `Sources/Reisen/App/ContentView.swift` / `TripDetailView.swift` / Offen-Zweig — Notification `.reisenPasteBooking`
- Create: `Sources/Reisen/App/PasteImportFlow.swift` (Sheet: PCC-Confirm, Progress, CandidateList, dann bestehende `bookingEditorSession`)

**Interfaces:**
- Consumes: `PasteImportModelResolver`, `FoundationModelsPasteImportAvailability`, `FoundationModelsPasteImportExtractor`, `PasteImportPipeline`
- Produces: Queue `[PasteImportCandidate]`; Create vs `bookingEditorSession = .edit`

Flow:
1. Clipboard: `NSPasteboard` String, sonst TIFF/PDF Data → `PasteImportSource.validated()`.
2. `kind = Resolver.resolve(availability.availability())`. Unavailable → Control disabled, kein Sheet.
3. PCC → Bestätigungs-Alert (L10n pcc_confirm_*). Abbrechen = kein Lauf.
4. `extract` in Task; Abbrechen setzt `CancellationError` → Alert `paste_import.error_model`, keine Teil-Liste.
5. Pipeline mit allen `Booking` aus dem Store (gleiche Quelle wie Sync-Index: Domain-Mapper über vorhandene SDBookings).
6. 0 Kandidaten → Leerzustand-L10n, kein Dummy.
7. Nutzer Continue → nächster selektierter Candidate: Neu → `bookingEditorSession = .create` + Prefill-Draft ersetzen; Unique → `selectedTimelineID` / Open-Booking selektieren + `bookingEditorSession = .edit`. Queue rest.

Datei-Import: `NSOpenPanel` pdf/png/jpeg zusätzlich zum Clipboard, gleicher Flow.

⌘V nicht ersetzen.

- [ ] **Step 1:** Notification-Name neben `reisenAddBooking` in `SidebarSelection.swift` (dort liegen die anderen `.reisen*`).
- [ ] **Step 2:** Commands + Flow verdrahten.
- [ ] **Step 3:** `swift build --target Reisen`
- [ ] **Step 4: Commit** `feat: add macOS paste-booking command and review flow`

Manueller Smoke (nicht CI): Reise offen, ⌘⇧V mit Text „Hotel Berlin Check-in 2026-09-01“, Editor erscheint.

---

### Task 11: iOS-Einstieg + Share-Extension

**Files:**
- Modify: `project.yml` — Target `ReisenPasteImportShare` (`type: app-extension`), bundle `de.reisen.Reisen.ios.share` / Private-Variante oder **eine** Extension nur in `ReiseniOSPrivate` **und** `ReiseniOS` embedden (zwei `embed`/`dependencies`). App Group `group.de.reisen.Reisen.pasteimport`.
- Create: `Apps/ReisenPasteImportShare/ShareViewController.swift` (oder `ShareExtension.swift`) — liest `NSExtensionItem`, schreibt Datei `payload.bin` + `meta.json` (`kind: text|image|pdf`) in `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`, öffnet Host via `https://reisen.app/paste-import` **oder** vorhandenes URL-Scheme aus Info.plist. Kein SwiftData.
- Modify: Host `ReiseniOSApp.swift` / `OffenTab` / Trip — `onOpenURL` consume + delete file; Fehler `paste_import.error_handoff`.
- Modify: Entitlements beider iOS-Apps + Extension: App Group.
- iOS UI: Toolbar-Menü gleicher L10n-Key, `PhotosPicker`/`fileImporter` analog macOS-Flow (`PasteImportFlow` nach SharedUI ziehen, wenn Task 10 ihn app-spezifisch gelassen hat — dann in diesem Task nach `Sources/ReisenSharedUI/PasteImport/PasteImportFlow.swift` verschieben, macOS nur Clipboard/OpenPanel-Adapter).

**SSOT-Flow:** `PasteImportFlow` muss in SharedUI liegen, bevor iOS ihn nutzt. Wenn Task 10 ihn unter `Sources/Reisen/` angelegt hat, hier verschieben (ein Commit, keine parallele Kopie).

- [ ] **Step 1:** `PasteImportFlow` in SharedUI, Plattform-Hooks (`PasteImportSourceReading`) als Protocol.
- [ ] **Step 2:** Share-Extension + App Group + `generate-ios-project.sh` (Projekt wird nicht committed).
- [ ] **Step 3:** `bash ./Scripts/generate-ios-project.sh` muss Exit 0 sein.
- [ ] **Step 4: Commit** (ohne `Reisen.xcodeproj`) `feat: add iOS paste-import entry and share extension`

---

### Task 12: Privacy-HTML

**Files:**
- Modify: `docs/legal/privacy.html`
- Modify: `docs/legal/en/privacy.html`
- Modify: `Tests/ReisenDomainTests/LegalPrivacyContentTests.swift`

Neuen Abschnitt nach „Welche Daten verarbeitet Reisen?“:

DE-Needles für den Test (zu den bestehenden Arrays **hinzufügen**): `Paste-Import`, `Private Cloud Compute`, `ephemer`.
EN: `Paste import`, `Private Cloud Compute`, `ephemeral`.

Text: Nutzer kann Text/Bild/PDF einfügen; Verarbeitung on-device oder nach Bestätigung über Apple Private Cloud Compute; Datei wird nicht an der Buchung gespeichert; kein Drittanbieter-LLM.

- [ ] **Step 1:** Test-Needles zuerst → RED
- [ ] **Step 2:** HTML beide Sprachen
- [ ] **Step 3:** `swift test --filter privacyPolicy` GREEN
- [ ] **Step 4: Commit** `docs: describe paste-import and Private Cloud Compute in privacy policy`

---

## Spec-Coverage (Self-Review)

| Spec | Task |
|---|---|
| Quelle Text/Bild/PDF ephemer, leer = Fehler | 1, 8, 11 |
| Filter Typ+startAt, endAt-Platzhalter | 2 |
| Match Index + kein Fingerprint bei Platzhalter + ambiguous Hinweis | 3, 5, 9 |
| Merge nur Lücken, Trip/Provider/URL/lastSyncedAt | 4, 9 |
| Resolver PCC > On-Device > unavailable, kein Stufenwechsel nach Fehler | 5, 8, 10 |
| Port mockbar, CI ohne Live-Modell | 5, 7 |
| `@Generable`/DTO Mapper, unknown type nicht `.other` | 7 |
| PDFKit, Bilder über SDK-Attachment | 8 |
| Editor ohne `createDefault`-Minuten | 9 |
| macOS Menü ⌘⇧V, ⌘V unangetastet, PCC-Sheet, Progress, Queue | 10 |
| iOS + Share App Group, kein SwiftData in Extension | 11 |
| Privacy PCC + ephemer | 12 |
| Alle BookingTypes | Filter nutzt `BookingType(rawValue:)` für alle Cases (Task 7 Mapper) |
| Drittanbieter-LLM / F05 / Auto-Upsert | bewusst keine Tasks |

**Verworfene Parallel-Wege:** `SyncBookingDraftApplier`, Upsert-Loop, ChatGPT/Perplexity, Silent OCR wenn Attachments fehlen.
