# Paste-Import Failed Feature-Request Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nach 0 Kandidaten oder Modellfehler kann der Nutzer nach Bestätigung ein öffentliches `kind/feature`-Issue mit dem Quelldokument anlegen.

**Architecture:** Domain entscheidet das Angebot und formt das Dokument. AppCore hängt `GitHubIssueKind.feature` und Base64-Kommentare an den bestehenden `GitHubIssueReporter`. SharedUI ist Bestätigungs-Chrome. macOS/iOS-Sessions behalten die Quelle und rufen `submit` erst nach Bestätigung.

**Tech Stack:** Swift 6.3, Swift Testing, bestehender GitHub-Issues-Client (PAT Issues read/write), SwiftUI Alerts/Sheets, L10n xcstrings.

**Spec:** [`docs/superpowers/specs/2026-08-29-paste-import-failed-feature-request-design.md`](../specs/2026-08-29-paste-import-failed-feature-request-design.md)

## Global Constraints

- Schichten: Domain ohne GitHub/FoundationModels/UIKit; Issues nur in ReisenAppCore; SharedUI ohne ReisenPasteImport und ohne HTTP.
- Kein `GitHubIssueAutoReport`. Kein Issue ohne UI-Bestätigung.
- PAT bleibt Issues read/write, nur `rosch100/Reisen`. Kein Contents, kein Gist, kein `uploads.github.com`.
- Keine stillen Fallbacks: zu groß / kein Token / HTTP → Fehler, kein URL-only-Issue das einen Anhang behauptet.
- TDD: Stub kompilieren, Test, RED = Assert-Fail, dann Implementierung.
- Tests: `swift test --filter <Name>`; CI-Parität `bash ./Scripts/ci-test.sh`.
- L10n: neue `L10nKey` in `Localizable.xcstrings` de+en; `L10nTests` grün.
- iOS nur über `bash ./Scripts/generate-ios-project.sh` / `ios-test.sh` wenn iOS-Dateien ändern.
- Default-Simulator: `iPad Pro 13-inch (M5)`.

---

## File map

| Datei | Verantwortung |
|---|---|
| `Sources/ReisenDomain/PasteImport/PasteImportFailedRecognition.swift` | Gate und Grund |
| `Sources/ReisenDomain/PasteImport/PasteImportSource.swift` | Dateiname, MIME, Payload für den Mail-Anhang |
| `Sources/ReisenAppCore/GitHubIssues/GitHubIssuesRepo.swift` | `GitHubIssueKind.feature` |
| `Sources/ReisenAppCore/GitHubIssues/GitHubIssueAttachmentCodec.swift` | Base64-Kommentare, 512_000-Limit |
| `Sources/ReisenAppCore/GitHubIssues/GitHubIssueReporter.swift` | `attachments:` nach Create |
| `Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequest.swift` | submit nach Bestätigung |
| `Sources/ReisenSharedUI/PasteImport/PasteImportFailedFeatureRequestChrome.swift` | Bestätigungs-Presentation |
| `Sources/Reisen/App/PasteImportMacSession.swift` | Quelle halten, Angebot, Bestätigung |
| `Apps/ReiseniOS/Shared/PasteImportIOSSession.swift` + `PasteImportHost.swift` | analog iOS |
| `docs/legal/privacy.html`, `en/privacy.html` | öffentlich, Bestätigung, Dokument |
| `Sources/ReisenDomain/Resources/Localizable.xcstrings` + `L10nKey.swift` | neue Keys |

---

### Task 1: Domain-Gate

**Files:**
- Create: `Sources/ReisenDomain/PasteImport/PasteImportFailedRecognition.swift`
- Test: `Tests/ReisenDomainTests/PasteImportFailedRecognitionTests.swift`

**Interfaces:**
- Consumes: `PasteImportFailure`
- Produces: `PasteImportFailedRecognitionReason` (`noCandidates` \| `model`); `PasteImportFailedRecognition.shouldOffer(candidateCount:)`; `shouldOffer(failure:)`

- [ ] **Step 1: Kompilierender Stub**

```swift
import Foundation

public enum PasteImportFailedRecognitionReason: Equatable, Sendable {
    case noCandidates
    case model
}

public enum PasteImportFailedRecognition: Sendable {
    public static func shouldOffer(candidateCount: Int) -> Bool {
        false
    }

    public static func shouldOffer(failure: PasteImportFailure) -> Bool {
        false
    }
}
```

- [ ] **Step 2: Failing tests**

```swift
import Testing
import ReisenDomain

@Test func pasteImportFailedRecognition_offersWhenCandidateCountIsZero() {
    #expect(PasteImportFailedRecognition.shouldOffer(candidateCount: 0))
}

@Test func pasteImportFailedRecognition_doesNotOfferWhenCandidatesExist() {
    #expect(!PasteImportFailedRecognition.shouldOffer(candidateCount: 1))
}

@Test func pasteImportFailedRecognition_offersModelFailureOnly() {
    #expect(PasteImportFailedRecognition.shouldOffer(failure: .model))
    #expect(!PasteImportFailedRecognition.shouldOffer(failure: .source))
    #expect(!PasteImportFailedRecognition.shouldOffer(failure: .modelUnavailable))
    #expect(!PasteImportFailedRecognition.shouldOffer(failure: .imageUnsupported))
}
```

Run: `swift test --filter pasteImportFailedRecognition_`
Expected: FAIL — `shouldOffer` returns false.

- [ ] **Step 3: Minimal implementation**

```swift
public static func shouldOffer(candidateCount: Int) -> Bool {
    candidateCount == 0
}

public static func shouldOffer(failure: PasteImportFailure) -> Bool {
    failure == .model
}
```

- [ ] **Step 4: Tests green**

Run: `swift test --filter pasteImportFailedRecognition_`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/PasteImport/PasteImportFailedRecognition.swift Tests/ReisenDomainTests/PasteImportFailedRecognitionTests.swift
git commit -m "$(cat <<'EOF'
feat: gate feature-request after failed paste recognition

EOF
)"
```

---

### Task 2: Failed document from source

**Files:**
- Create: `Sources/ReisenDomain/PasteImport/PasteImportFailedDocument.swift`
- Test: `Tests/ReisenDomainTests/PasteImportFailedDocumentTests.swift`

**Interfaces:**
- Consumes: `PasteImportSource`
- Produces: `PasteImportFailedDocument` mit `fileName`, `mimeType`, `text` (optional), `binary` (optional). Genau eine Payload: Text-Quelle → `text` gesetzt, `binary == nil`; Bild/PDF → `binary` gesetzt, `text == nil`.

- [ ] **Step 1: Stub**

```swift
import Foundation

public struct PasteImportFailedDocument: Equatable, Sendable {
    public let fileName: String
    public let mimeType: String
    public let text: String?
    public let binary: Data?

    public static func from(_ source: PasteImportSource) -> PasteImportFailedDocument {
        PasteImportFailedDocument(fileName: "paste.txt", mimeType: "text/plain", text: "", binary: nil)
    }
}
```

- [ ] **Step 2: Failing tests**

```swift
import Foundation
import Testing
import ReisenDomain

@Test func pasteImportFailedDocument_textUsesBodyNotBinary() {
    let doc = PasteImportFailedDocument.from(.text("Hallo"))
    #expect(doc.fileName == "paste.txt")
    #expect(doc.mimeType == "text/plain")
    #expect(doc.text == "Hallo")
    #expect(doc.binary == nil)
}

@Test func pasteImportFailedDocument_imageIsBinary() {
    let bytes = Data([0x89, 0x50, 0x4E, 0x47])
    let doc = PasteImportFailedDocument.from(.image(bytes))
    #expect(doc.fileName == "paste-image.bin")
    #expect(doc.mimeType == "application/octet-stream")
    #expect(doc.text == nil)
    #expect(doc.binary == bytes)
}

@Test func pasteImportFailedDocument_pdfIsBinary() {
    let bytes = Data([0x25, 0x50, 0x44, 0x46])
    let doc = PasteImportFailedDocument.from(.pdf(bytes))
    #expect(doc.fileName == "paste.pdf")
    #expect(doc.mimeType == "application/pdf")
    #expect(doc.text == nil)
    #expect(doc.binary == bytes)
}
```

Run: `swift test --filter pasteImportFailedDocument_`
Expected: FAIL on image/pdf (stub always text).

- [ ] **Step 3: Implementation**

```swift
public static func from(_ source: PasteImportSource) -> PasteImportFailedDocument {
    switch source {
    case .text(let text):
        return PasteImportFailedDocument(
            fileName: "paste.txt",
            mimeType: "text/plain",
            text: text,
            binary: nil
        )
    case .image(let data):
        return PasteImportFailedDocument(
            fileName: "paste-image.bin",
            mimeType: "application/octet-stream",
            text: nil,
            binary: data
        )
    case .pdf(let data):
        return PasteImportFailedDocument(
            fileName: "paste.pdf",
            mimeType: "application/pdf",
            text: nil,
            binary: data
        )
    }
}
```

- [ ] **Step 4: Tests green** — `swift test --filter pasteImportFailedDocument_`

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/PasteImport/PasteImportFailedDocument.swift Tests/ReisenDomainTests/PasteImportFailedDocumentTests.swift
git commit -m "$(cat <<'EOF'
feat: map paste source to failed-recognition document

EOF
)"
```

---

### Task 3: `GitHubIssueKind.feature`

**Files:**
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssuesRepo.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift` (Kind-Tests)
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueTitleTests.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueNewIssueURLTests.swift` (ein Compose-Test für feature.yml / `want`)

**Interfaces:**
- Consumes: bestehendes `feature.yml` (`id: want`, Label `kind/feature`)
- Produces: `GitHubIssueKind.feature` mit `displayName == "Feature"`, `titlePrefix == "[Feature]"`, `issueForm.templateFileName == "feature.yml"`, `fieldID == "want"`, `githubLabels == ["kind/feature", "source/in-app"]`

- [ ] **Step 1: Failing tests zuerst an bestehende Dateien anhängen**

In `githubIssueKind_issueTemplatesDeclareKindNotInAppSource` die Schleife auf `[GitHubIssueKind.error, .feedback, .feature]` erweitern — kompiliert nicht, solange `.feature` fehlt. Zuerst `.feature` als Stub-Case ohne Formular verdrahten, dann Tests auf die Spec-Werte stellen.

Praktisch: Case hinzufügen (sonst kein RED-Compile des Tests), Tests schreiben die **falsche** Formular-Verdrahtung des Stubs treffen:

Stub in `GitHubIssuesRepo.swift` — `case feature` mit vorläufig denselben Werten wie `.feedback` (falsch).

Test:

```swift
@Test func githubIssueKind_featureUsesFeatureTemplate() {
    #expect(GitHubIssueKind.feature.displayName == "Feature")
    #expect(GitHubIssueKind.feature.issueForm.templateFileName == "feature.yml")
    #expect(GitHubIssueKind.feature.issueForm.fieldID == "want")
    #expect(GitHubIssueKind.feature.githubLabels == ["kind/feature", "source/in-app"])
}

@Test func githubIssueTitle_reportTitlePrefixesFeature() {
    #expect(
        GitHubIssueTitle.reportTitle(kind: .feature, message: "Paste-Import: Dokument nicht erkannt")
            == "[Feature] Paste-Import: Dokument nicht erkannt"
    )
}
```

`githubIssueKind_issueTemplatesDeclareKindNotInAppSource`: `.feature` in die Liste.

NewIssueURL:

```swift
@Test func githubIssueNewIssueURL_featureUsesWantField() throws {
    let url = try #require(
        GitHubIssueNewIssueURL.compose(
            kind: .feature,
            message: "Dokument nicht erkannt",
            providerID: nil
        )
    )
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    #expect(query.first { $0.name == "template" }?.value == "feature.yml")
    #expect(query.first { $0.name == "labels" }?.value == "kind/feature,source/in-app")
    #expect(query.contains { $0.name == "want" })
}
```

Run: `swift test --filter githubIssueKind_feature --filter githubIssueTitle_reportTitlePrefixesFeature --filter githubIssueNewIssueURL_feature`
Expected: FAIL (feedback-Formular / `[Feedback]`).

- [ ] **Step 2: Kind verdrahten**

```swift
public enum GitHubIssueKind: String, Sendable {
    case error
    case feedback
    case feature

    public var displayName: String {
        switch self {
        case .error: "Fehler"
        case .feedback: "Feedback"
        case .feature: "Feature"
        }
    }

    public var repeatReportLabel: String {
        switch self {
        case .error: "Fehlerbericht"
        case .feedback, .feature: displayName
        }
    }

    public var issueForm: IssueForm {
        switch self {
        case .error:
            IssueForm(templateFileName: "bug.yml", fieldID: "what")
        case .feedback:
            IssueForm(templateFileName: "feedback.yml", fieldID: "feedback")
        case .feature:
            IssueForm(templateFileName: "feature.yml", fieldID: "want")
        }
    }
}
```

`githubLabels` bleibt `"kind/\(rawValue)"` → `kind/feature`.

- [ ] **Step 3: Tests green**

- [ ] **Step 4: Commit**

```bash
git add Sources/ReisenAppCore/GitHubIssues/GitHubIssuesRepo.swift Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift Tests/ReisenAppCoreTests/GitHubIssueTitleTests.swift Tests/ReisenAppCoreTests/GitHubIssueNewIssueURLTests.swift
git commit -m "$(cat <<'EOF'
feat: add GitHubIssueKind.feature for in-app feature requests

EOF
)"
```

---

### Task 4: Attachment-Codec und Reporter

**Files:**
- Create: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueAttachment.swift`
- Create: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueAttachmentCodec.swift`
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueReporter.swift` — `report(..., attachments: [GitHubIssueAttachment] = [])`
- Modify: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueReporter.swift` Error um `attachmentTooLarge`
- Test: `Tests/ReisenAppCoreTests/GitHubIssueAttachmentCodecTests.swift`
- Modify: `Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift`

**Interfaces:**
- Consumes: `GitHubIssueSubmitting.comment`
- Produces: Kommentar-Bodies mit Marker `reisen-paste-import-attachment`; `maxSourceBytes = 512_000`; `commentBodyBudget = 60_000`. Über Limit: `GitHubIssueReporterError.attachmentTooLarge`, **kein** `createIssue`. Bestehendes Fingerprint-Issue: keine Attachment-Kommentare.

- [ ] **Step 1: Typen + Stub-Codec der immer `[]` liefert, Reporter ignoriert attachments**

```swift
public struct GitHubIssueAttachment: Equatable, Sendable {
    public let fileName: String
    public let mimeType: String
    public let data: Data

    public init(fileName: String, mimeType: String, data: Data) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }
}

public enum GitHubIssueAttachmentCodec: Sendable {
    public static let marker = "reisen-paste-import-attachment"
    public static let maxSourceBytes = 512_000
    public static let commentBodyBudget = 60_000

    public static func comments(for attachment: GitHubIssueAttachment) throws -> [String] {
        []
    }
}
```

Error:

```swift
case attachmentTooLarge(maxBytes: Int)
```

`errorDescription`: `"Dokument ist größer als \(maxBytes) Bytes"`

Reporter-Signatur um Default `attachments: [GitHubIssueAttachment] = []` und `fingerprintMessage: String? = nil` erweitern. `fingerprintMessage ?? redactedMessage` für `GitHubIssueFingerprint`. Attachments in diesem Step noch ignorieren, bis Tests rot sind.

- [ ] **Step 2: Failing tests**

```swift
@Test func githubIssueAttachmentCodec_rejectsEmptyData() {
    let attachment = GitHubIssueAttachment(
        fileName: "a.bin",
        mimeType: "application/octet-stream",
        data: Data()
    )
    #expect(throws: GitHubIssueAttachmentCodecError.empty) {
        _ = try GitHubIssueAttachmentCodec.comments(for: attachment)
    }
}
```

Codec-Error:

```swift
public enum GitHubIssueAttachmentCodecError: Error, Equatable {
    case empty
    case tooLarge(maxBytes: Int)
}
```

Reporter mappt `tooLarge` auf `GitHubIssueReporterError.attachmentTooLarge`. `empty` nicht über Reporter-UI (Domain liefert keine leeren Binaries nach `validated()`).

Tests:

```swift
@Test func githubIssueAttachmentCodec_splitsUnderBudget() throws {
    let data = Data(repeating: 0x41, count: 100)
    let comments = try GitHubIssueAttachmentCodec.comments(
        for: GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)
    )
    #expect(!comments.isEmpty)
    #expect(comments.allSatisfy { $0.contains(GitHubIssueAttachmentCodec.marker) })
    #expect(comments.allSatisfy { $0.count <= GitHubIssueAttachmentCodec.commentBodyBudget })
    #expect(comments.joined().contains("paste.pdf"))
}

@Test func githubIssueAttachmentCodec_rejectsOverMaxBytes() {
    let data = Data(repeating: 1, count: GitHubIssueAttachmentCodec.maxSourceBytes + 1)
    #expect(throws: GitHubIssueAttachmentCodecError.tooLarge(maxBytes: GitHubIssueAttachmentCodec.maxSourceBytes)) {
        _ = try GitHubIssueAttachmentCodec.comments(
            for: GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)
        )
    }
}

@Test @MainActor func githubIssueReporter_attachmentsPostCommentsAfterCreate() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let data = Data("pdf".utf8)
    _ = try await reporter.report(
        kind: .feature,
        message: "Paste-Import: Dokument nicht erkannt",
        providerID: nil,
        attachments: [GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)]
    )
    #expect(client.createCount == 1)
    #expect(client.commentCount >= 1)
}

@Test @MainActor func githubIssueReporter_tooLargeAttachmentCreatesNoIssue() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let data = Data(repeating: 1, count: GitHubIssueAttachmentCodec.maxSourceBytes + 1)
    await #expect(throws: GitHubIssueReporterError.attachmentTooLarge(maxBytes: GitHubIssueAttachmentCodec.maxSourceBytes)) {
        try await reporter.report(
            kind: .feature,
            message: "x",
            providerID: nil,
            attachments: [GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: data)]
        )
    }
    #expect(client.createCount == 0)
}

@Test @MainActor func githubIssueReporter_attachmentsWithoutTokenMakeNoHTTP() async {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { throw GitHubIssueTokenError.notEmbedded },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    await #expect(throws: GitHubIssueTokenError.notEmbedded) {
        try await reporter.report(
            kind: .feature,
            message: "x",
            providerID: nil,
            attachments: [GitHubIssueAttachment(fileName: "paste.pdf", mimeType: "application/pdf", data: Data("pdf".utf8))]
        )
    }
    #expect(client.createCount == 0)
    #expect(client.commentCount == 0)
}
```

Bestehende `GitHubIssueAutoReportTests` nicht ändern (kein Aufruf aus Paste-Import). Mock zählt `commentCount` weiter (tut er schon).

Run: `swift test --filter githubIssueAttachment --filter githubIssueReporter_attachments --filter githubIssueReporter_tooLarge`
Expected: FAIL (leere comments / create trotzdem).

- [ ] **Step 3: Codec**

Kommentarformat (ein Teil):

```
<!-- reisen-paste-import-attachment -->
fileName: paste.pdf
mimeType: application/pdf
encoding: base64
part: 1/1

<base64>
```

`comments(for:)`:

1. `guard !data.isEmpty else { throw .empty }`
2. `guard data.count <= maxSourceBytes else { throw .tooLarge }`
3. Base64 der gesamten Data, dann in Chunks so schneiden, dass Header + Chunk ≤ `commentBodyBudget`.

Reporter `report`:

1. Bestehende Token-/Corrupt-Guards.
2. Wenn `attachments` nicht leer: `try` Codec für jedes; bei `tooLarge`/`empty` → `GitHubIssueReporterError.attachmentTooLarge` bzw. rethrow empty als `attachmentTooLarge` nur für tooLarge; `empty` als `GitHubIssueReporterError` neuen Case `attachmentEmpty` **nicht** — empty nach validated Quelle kommt nicht vor; Codec empty → `attachmentTooLarge` wäre falsch. Case `attachmentInvalid` mit Description `"Dokumentanhang ist leer"`.
3. Spec vereinfachen im Code: `GitHubIssueReporterError.attachmentRejected(String)` vermeiden. Zwei Cases: `attachmentTooLarge(maxBytes:)`, `attachmentEmpty`.
4. **Vor** `createIssue` die Comment-Strings bauen.
5. Nach erfolgreichem **neuen** Create: `comment` je String.
6. Fingerprint-Treffer (existierendes Issue): Attachments **nicht** nochmal posten (wie Spec).
7. Fingerprint: `GitHubIssueFingerprint.hex(kind:kind, message: fingerprintMessage ?? redactedMessage)`.

`errorDescription` für `attachmentEmpty`: `"Dokumentanhang ist leer"`.

- [ ] **Step 4: Tests green**

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/GitHubIssues/GitHubIssueAttachment.swift Sources/ReisenAppCore/GitHubIssues/GitHubIssueAttachmentCodec.swift Sources/ReisenAppCore/GitHubIssues/GitHubIssueReporter.swift Tests/ReisenAppCoreTests/GitHubIssueAttachmentCodecTests.swift Tests/ReisenAppCoreTests/GitHubIssueReporterTests.swift
git commit -m "$(cat <<'EOF'
feat: attach failed-import documents as GitHub issue comments

EOF
)"
```

---

### Task 5: Submit-Orchestrierung

**Files:**
- Create: `Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequest.swift`
- Test: `Tests/ReisenAppCoreTests/PasteImportFailedFeatureRequestTests.swift`

**Interfaces:**
- Consumes: `PasteImportSource` (Payload, Dateiname, MIME), `PasteImportFailedRecognitionReason`, `GitHubIssueReporter.report`
- Produces: `PasteImportFailedFeatureRequest.submit(source:reason:reporter:reporterGitHubUsername:) async throws -> PasteImportFailedFeatureRequestOutcome`
- Message-Body enthält Grund und Quellart; `titleOverride` = `[Feature] Paste-Import: Dokument nicht erkannt`
- Fingerprint-stabil: Reporter-Parameter `fingerprintMessage` = `kind/feature` + SHA256 der Quellbytes **ohne** Erkennungsgrund. Body-`message` darf den Grund enthalten. Derselbe Anhang nach `.noCandidates` und `.model` → ein Create.
- Text/Bild/PDF: `attachments: []`; Original nur im Mail-Draft

- [ ] **Step 1: Stub der `fatalError`/`throw` nicht nutzt — gibt ein Dummy-Issue zurück** (verboten). Stub wirft `GitHubIssueTokenError.notEmbedded` immer — Test erwartet Create. Besser: Stub ruft Reporter mit `kind: .error` (falsch), Test erwartet `.feature` in `lastCreate`.

```swift
@MainActor
public enum PasteImportFailedFeatureRequest {
    public static let titleOverride = GitHubIssueTitle.reportTitle(
        kind: .feature,
        message: "Paste-Import: Dokument nicht erkannt"
    )

    public static func submit(
        source: PasteImportSource,
        reason: PasteImportFailedRecognitionReason,
        reporter: GitHubIssueReporter,
        reporterGitHubUsername: String?
    ) async throws -> GitHubCreatedIssue {
        try await reporter.report(
            kind: .feedback,
            message: "wrong",
            providerID: nil,
            titleOverride: nil,
            reporterGitHubUsername: reporterGitHubUsername
        )
    }
}
```

- [ ] **Step 2: Failing tests**

```swift
@Test @MainActor func pasteImportFailedFeatureRequest_textCreatesFeatureWithoutAttachment() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .text("PNR ABC"),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    let created = try #require(client.lastCreate)
    #expect(created.labels.contains("kind/feature"))
    #expect(created.title.hasPrefix("[Feature]"))
    #expect(created.body.contains("PNR ABC") || created.body.contains("ABC"))
    #expect(client.commentCount == 0)
}

@Test @MainActor func pasteImportFailedFeatureRequest_pdfAttachesBinary() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .pdf(pdf),
        reason: .model,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
    #expect(client.commentCount >= 1)
    #expect(client.lastCreate?.labels.contains("kind/feature") == true)
}

@Test @MainActor func pasteImportFailedFeatureRequest_sameDocumentDifferentReasonReusesIssue() async throws {
    let client = MockGitHubIssues()
    let reporter = GitHubIssueReporter(
        client: client,
        tokenProvider: { "token" },
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        persistenceURL: nil
    )
    let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .pdf(pdf),
        reason: .noCandidates,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    _ = try await PasteImportFailedFeatureRequest.submit(
        source: .pdf(pdf),
        reason: .model,
        reporter: reporter,
        reporterGitHubUsername: nil
    )
    #expect(client.createCount == 1)
}
```

`SecretRedactor` darf Tokens redigieren, nicht den Test-PNR „ABC“ verschlucken — wenn er zu aggressiv ist, Assert auf `noCandidates` / `pdf` / `reisen-source-sha256` statt Rohtext.

Run: `swift test --filter pasteImportFailedFeatureRequest_`
Expected: FAIL (kind/feedback, keine comments).

- [ ] **Step 3: Implementation**

Message bauen:

```
reason line: noCandidates → "Keine Buchung erkannt"; model → "Modellfehler"
source kind: text|image|pdf
reisen-source-sha256: hex
if text: redacted text
```

SHA256: `CryptoKit` wie `GitHubIssueFingerprint`. Text: UTF-8 der Quelle; Binary: die Data.

`titleOverride`: `PasteImportFailedFeatureRequest.titleOverride`.

Attachments nur wenn `binary != nil`.

Fingerprint: `fingerprintMessage` = `"paste-import-failed\n" + sha256Hex`. Body-Message enthält zusätzlich den Grund (`noCandidates`/`model`).

Test: zwei `submit` derselben PDF, einmal `.noCandidates` und einmal `.model` → `createCount == 1`.

- [ ] **Step 4: Tests green**

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequest.swift Tests/ReisenAppCoreTests/PasteImportFailedFeatureRequestTests.swift
git commit -m "$(cat <<'EOF'
feat: submit paste-import failures as kind/feature issues

EOF
)"
```

---

### Task 6: Entry — Flow, SharedUI-Sheet, Sessions, L10n, Privacy

**Files:**
- Create: `Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequestFlow.swift`
- Test: `Tests/ReisenAppCoreTests/PasteImportFailedFeatureRequestFlowTests.swift`
- Create: `Sources/ReisenSharedUI/PasteImport/PasteImportFailedFeatureRequestChrome.swift`
- Create: `Sources/ReisenSharedUI/PasteImport/PasteImportCandidateSheet.swift` (heute privat dupliziert in Mac-Session und iOS-Host)
- Create: `Sources/ReisenSharedUI/PasteImport/PasteImportCandidateSheetPresentation.swift`
- Test: `Tests/ReisenSharedUITests/PasteImportFailedFeatureRequestChromeTests.swift`
- Test: `Tests/ReisenSharedUITests/PasteImportCandidateSheetPresentationTests.swift`
- Modify: `Sources/ReisenSharedUI/PasteImport/PasteImportCandidateList.swift`
- Modify: `Sources/Reisen/App/PasteImportMacSession.swift` + Flow-Modifier — Sheet aus SharedUI, Alerts an Flow
- Modify: `Apps/ReiseniOS/Shared/PasteImportIOSSession.swift`, `PasteImportHost.swift`
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Modify: `docs/legal/privacy.html`, `docs/legal/en/privacy.html`
- Modify: `Tests/ReisenDomainTests/LegalPrivacyContentTests.swift` Needles: DE `Feature-Request`, `Bestätigung`, `öffentlich`; EN `feature request`, `confirmation`, `public`
- Modify: `docs/superpowers/specs/2026-08-28-paste-import-design.md` — unter Fehler ein Satz + Link
- Modify: `docs/ci/github-issues-token.md` — Issues-PAT, Anhang über Kommentare, kein Contents

**Interfaces:**
- Consumes: Gate, `PasteImportFailedFeatureRequest.submit`
- Produces: `PasteImportFailedFeatureRequestFlow` (eine Machine für Mac+iOS); Sheet-Presentation; **kein** `PublicGitHubIssueReportActions`

Neue Keys (xcstrings de/en, `state: translated`):

| Key | de | en |
|---|---|---|
| `paste_import.feature_request` | Als Feature-Request senden… | Send as feature request… |
| `paste_import.feature_request_title` | Öffentlicher Feature-Request | Public feature request |
| `paste_import.feature_request_message` | GitHub-Issues sind öffentlich. Das Dokument (Text, Bild oder PDF) wird angehängt und kann persönliche Daten enthalten. Nur senden, wenn du das akzeptierst. | GitHub issues are public. The document (text, image, or PDF) will be attached and may contain personal data. Send only if you accept that. |
| `paste_import.feature_request_send` | Senden | Send |
| `paste_import.feature_request_done` | Feature-Request angelegt. | Feature request created. |

```swift
public struct PasteImportFailedFeatureRequestPresentation: Equatable, Sendable {
    public let title: String
    public let message: String
    public let sendTitle: String
    public let cancelTitle: String
    public let offerTitle: String

    public init() {
        title = L10n.string(.pasteImportFeatureRequestTitle)
        message = L10n.string(.pasteImportFeatureRequestMessage)
        sendTitle = L10n.string(.pasteImportFeatureRequestSend)
        cancelTitle = L10n.string(.commonCancel)
        offerTitle = L10n.string(.pasteImportFeatureRequest)
    }
}

public struct PasteImportCandidateSheetPresentation: Equatable, Sendable {
    public let continueEnabled: Bool
    public let showsFeatureRequestButton: Bool

    public init(candidateCount: Int, canOfferFeatureRequest: Bool) {
        continueEnabled = candidateCount > 0
        showsFeatureRequestButton = candidateCount == 0 && canOfferFeatureRequest
    }
}
```

Flow (`@MainActor @Observable`):

```swift
public enum PasteImportFailedFeatureRequestPhase: Equatable, Sendable {
    case idle
    case offering
    case confirming
    case succeeded(URL)
    case submitFailed(String)
}

public final class PasteImportFailedFeatureRequestFlow {
    public private(set) var phase: PasteImportFailedFeatureRequestPhase = .idle
    public func noteEmptyCandidates() { /* offering if source already set by session */ }
    public func noteModelFailure() { }
    public func offer() { }
    public func cancelOffer() { } // zurück nach offering, Quelle bleibt in der Session
    public func confirm(source: PasteImportSource, reason: PasteImportFailedRecognitionReason, reporter: GitHubIssueReporter, reporterGitHubUsername: String?) async { }
}
```

Tests am Flow (Injector = Mock Reporter):

- `offer()` dann kein `confirm` → `createCount == 0`
- `confirm` ohne vorheriges `offer` → kein HTTP
- `noteEmptyCandidates` + `offer` + `confirm` → `submit`/`createCount == 1`
- `cancelOffer` nach `offer` → Phase `offering`, danach `confirm` ohne erneutes `offer` → kein HTTP
- Erfolg → `phase == .succeeded(url)`; UI bindet `PublicGitHubIssueLink`, nicht ReportActions

Mac/iOS: Session hält `source` und den Flow. `cancelOffer` setzt Session-Phase zurück auf choosing([]) bzw. failed(model) — **kein** `reset`. Erfolg: Alert mit `PublicGitHubIssueLink(url:)`. Fehler: `submitFailed` Text, Quelle bleibt.

Sheet aus Apps nach SharedUI ziehen; beide Hosts importieren ihn. Feature-Button ruft `flow.offer` (nicht `submit`).

- [ ] **Step 1: L10n Keys + xcstrings gleichzeitig** (sonst `l10n_allKeysResolve` rot). Presentation-Tests.

- [ ] **Step 2: Flow-Tests RED** (Stub: `confirm` no-op) dann Implementierung.

- [ ] **Step 3: Sheet-Presentation-Tests** (`showsFeatureRequestButton == true` nur bei 0 Kandidaten und canOffer). CandidateList-Button wenn Presentation das sagt.

- [ ] **Step 4: Sessions/Host verdrahten; Privacy; Spec-Link; Token-Doku.** `swift test --filter pasteImportFailed --filter l10n_allKeys --filter privacyPolicy`. iOS: `bash ./Scripts/generate-ios-project.sh` und `bash ./Scripts/ios-test.sh`.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/PasteImport/PasteImportFailedFeatureRequestFlow.swift Sources/ReisenSharedUI/PasteImport Sources/Reisen/App/PasteImportMacSession.swift Apps/ReiseniOS/Shared/PasteImportIOSSession.swift Apps/ReiseniOS/Shared/PasteImportHost.swift Sources/ReisenDomain/Localization/L10nKey.swift Sources/ReisenDomain/Resources/Localizable.xcstrings docs/legal/privacy.html docs/legal/en/privacy.html Tests docs/superpowers/specs/2026-08-28-paste-import-design.md docs/ci/github-issues-token.md
git commit -m "$(cat <<'EOF'
feat: confirm before filing paste-import feature requests

EOF
)"
```

---

## Self-Review

1. Spec coverage: Gate, Bestätigung, kind/feature, Anhang Text/Bild/PDF, Limit, kein Auto-Report, kein Token-Issue ohne Anhang, kein Safari-URL-Fallback, Privacy, beide Einstiege über SharedUI-Sheet + Flow, open_gaps Live-GitHub — Tasks 1–6.
2. Keine TBD/TODO. Typen durchgängig.
3. `GitHubIssueKind.feature` rawValue `feature` → Label `kind/feature` = Template.

