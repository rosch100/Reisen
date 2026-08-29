import Foundation
import Testing
import ReisenDomain
import ReisenAppCore

@Test func pasteImportDrop_startsWhenIdleAndFileAccepted() {
    #expect(
        PasteImportDropStartResolver.decision(
            offeredURLCount: 1,
            acceptedFileCount: 1,
            isSessionActive: false
        ) == .start
    )
}

@Test func pasteImportDrop_ignoresWhileSessionIsActive() {
    #expect(
        PasteImportDropStartResolver.decision(
            offeredURLCount: 1,
            acceptedFileCount: 1,
            isSessionActive: true
        ) == .ignore
    )
    #expect(
        PasteImportDropStartResolver.decision(
            offeredURLCount: 2,
            acceptedFileCount: 0,
            isSessionActive: true
        ) == .ignore
    )
}

@Test func pasteImportDrop_failsWhenIdleButNoAcceptedFile() {
    #expect(
        PasteImportDropStartResolver.decision(
            offeredURLCount: 1,
            acceptedFileCount: 0,
            isSessionActive: false
        ) == .fail
    )
}

@Test func pasteImportDrop_ignoresEmptyOffer() {
    #expect(
        PasteImportDropStartResolver.decision(
            offeredURLCount: 0,
            acceptedFileCount: 0,
            isSessionActive: false
        ) == .ignore
    )
}

@Test func pasteImportDrop_shouldRetryInboxOnlyWhenLeavingActive() {
    #expect(PasteImportDropStartResolver.shouldRetryInbox(wasActive: true, isActive: false))
    #expect(!PasteImportDropStartResolver.shouldRetryInbox(wasActive: false, isActive: false))
    #expect(!PasteImportDropStartResolver.shouldRetryInbox(wasActive: true, isActive: true))
    #expect(!PasteImportDropStartResolver.shouldRetryInbox(wasActive: false, isActive: true))
}

@Test func pasteImportDropStart_ignoresEmptyOffer() {
    #expect(
        PasteImportDropStartResolver.resolve(urls: [], isSessionActive: false) == .ignore
    )
}

@Test func pasteImportDropStart_ignoresWhileSessionActive() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("paste-import-drop-\(UUID().uuidString).txt")
    try "Hallo".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(
        PasteImportDropStartResolver.resolve(urls: [url], isSessionActive: true) == .ignore
    )
}

@Test func pasteImportDropStart_failsUnsupportedURL() {
    let url = URL(fileURLWithPath: "/tmp/paste-import-unsupported-\(UUID().uuidString).xyz")
    guard case .fail(let message) = PasteImportDropStartResolver.resolve(
        urls: [url],
        isSessionActive: false
    ) else {
        Issue.record("expected fail")
        return
    }
    #expect(!message.isEmpty)
}

@Test func pasteImportDropStart_resolvesTextFile() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("paste-import-drop-\(UUID().uuidString).txt")
    try "PNR ABC".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    guard case .source(let source) = PasteImportDropStartResolver.resolve(
        urls: [url],
        isSessionActive: false
    ) else {
        Issue.record("expected source")
        return
    }
    #expect(source == .text("PNR ABC"))
}

@Test func pasteImportDropStart_applyDispatchesFailAndSource() {
    var failed: String?
    var started: PasteImportSource?
    PasteImportDropStart.fail("x").apply(onFail: { failed = $0 }, onSource: { _ in })
    #expect(failed == "x")
    PasteImportDropStart.source(.text("a")).apply(
        onFail: { _ in },
        onSource: { started = $0 }
    )
    #expect(started == .text("a"))
    PasteImportDropStart.ignore.apply(onFail: { _ in failed = "ignore" }, onSource: { _ in })
    #expect(failed == "x")
}

@Suite(.serialized)
@MainActor
struct PasteImportDropStartConsumeInboxTests {
    @Test func consumeInbox_emptyIsIgnore() {
        _ = PasteImportExternalFileInbox.take()
        #expect(PasteImportDropStartResolver.consumeInbox(isSessionActive: false) == .ignore)
    }

    @Test func consumeInbox_restoresWhenSessionActive() throws {
        _ = PasteImportExternalFileInbox.take()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste-import-inbox-\(UUID().uuidString).txt")
        try "PNR".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        PasteImportExternalFileInbox.offer([url])
        #expect(PasteImportDropStartResolver.consumeInbox(isSessionActive: true) == .ignore)
        #expect(PasteImportExternalFileInbox.take() == [url])
    }

    @Test func consumeInbox_resolvesWhenIdle() throws {
        _ = PasteImportExternalFileInbox.take()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste-import-inbox-\(UUID().uuidString).txt")
        try "PNR ABC".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        PasteImportExternalFileInbox.offer([url])
        guard case .source(let source) = PasteImportDropStartResolver.consumeInbox(
            isSessionActive: false
        ) else {
            Issue.record("expected source")
            return
        }
        #expect(source == .text("PNR ABC"))
        #expect(PasteImportExternalFileInbox.take().isEmpty)
    }

    @Test func consumeInbox_restoredUrlsStartWhenIdleAgain() throws {
        _ = PasteImportExternalFileInbox.take()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste-import-inbox-retry-\(UUID().uuidString).txt")
        try "PNR RETRY".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        PasteImportExternalFileInbox.offer([url])
        #expect(PasteImportDropStartResolver.consumeInbox(isSessionActive: true) == .ignore)
        guard case .source(let source) = PasteImportDropStartResolver.consumeInbox(
            isSessionActive: false
        ) else {
            Issue.record("expected source after idle")
            return
        }
        #expect(source == .text("PNR RETRY"))
        #expect(PasteImportExternalFileInbox.take().isEmpty)
    }
}
