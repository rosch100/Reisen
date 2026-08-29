import Foundation
import Testing
import ReisenAppCore

@Suite(.serialized)
@MainActor
struct PasteImportExternalFileInboxTests {
    @Test func offerThenTakeReturnsAndClears() {
        _ = PasteImportExternalFileInbox.take()
        let url = URL(fileURLWithPath: "/tmp/ticket.pdf")
        PasteImportExternalFileInbox.offer([url])
        #expect(PasteImportExternalFileInbox.take() == [url])
        #expect(PasteImportExternalFileInbox.take().isEmpty)
    }

    @Test func takeWithoutOfferIsEmpty() {
        _ = PasteImportExternalFileInbox.take()
        #expect(PasteImportExternalFileInbox.take().isEmpty)
    }
}
