import Foundation
import Testing
import ReisenDomain

@Test func portalCancelCompletion_opodoAlreadyCancelledText_isTrue() {
    let url = URL(string: "https://www.opodo.de/trips#/tripdetails/1")!
    #expect(
        PortalCancelCompletionDetector.looksCompleted(
            provider: .opodo,
            url: url,
            pageText: "Status: Bereits storniert am 1.9."
        )
    )
}

@Test func portalCancelCompletion_opodoWhitespaceVariant_isTrue() {
    #expect(
        PortalCancelCompletionDetector.looksCompleted(
            provider: .opodo,
            url: nil,
            pageText: "bereits   storniert"
        )
    )
}

@Test func portalCancelCompletion_opodoWithoutMarker_isFalse() {
    #expect(
        !PortalCancelCompletionDetector.looksCompleted(
            provider: .opodo,
            url: URL(string: "https://www.opodo.de/trips#/tripdetails/1"),
            pageText: "Buchung abbrechen / Diese Buchung stornieren"
        )
    )
}

@Test func portalCancelCompletion_opodoNilOrEmptyText_isFalse() {
    #expect(
        !PortalCancelCompletionDetector.looksCompleted(
            provider: .opodo,
            url: nil,
            pageText: nil
        )
    )
    #expect(
        !PortalCancelCompletionDetector.looksCompleted(
            provider: .opodo,
            url: nil,
            pageText: ""
        )
    )
}

@Test func portalCancelCompletion_otherProviders_alwaysFalse() {
    let text = "bereits storniert"
    for provider in ProviderID.syncProviderIDs where provider != .opodo {
        #expect(
            !PortalCancelCompletionDetector.looksCompleted(
                provider: provider,
                url: URL(string: "https://example.com/cancel"),
                pageText: text
            )
        )
    }
}

@Test func portalCancelCompletion_needsPageTextProbe_onlyOpodo() {
    #expect(PortalCancelCompletionDetector.needsPageTextProbe(provider: .opodo))
    #expect(!PortalCancelCompletionDetector.needsPageTextProbe(provider: .check24))
}
