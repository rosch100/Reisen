import Foundation
import Testing
import WebKit
@testable import ReisenCheck24
import ReisenDomain
import ReisenProviders

@Test("#90 Sync über any TravelProvider: Check24 nutzt dieselbe WKWebView, nicht Code 5")
@MainActor
func check24ExistentialMakeSyncSessionYieldsUsableWebView() throws {
    // Wie SyncStore: `any TravelProvider.makeSyncSession` (Extension-Default).
    // Der Extension-Default liefert `WebViewProviderSession`; `webView(from:)` extrahiert dieselbe `WKWebView`.
    let check24 = Check24TravelProvider()
    let provider: any TravelProvider = check24
    let webView = WKWebView()

    let session = provider.makeSyncSession(webView: webView)
    let extracted = try check24.webView(from: session)
    #expect(extracted === webView)
}

@Test("Check24 JavaScript-Bedingung unterscheidet Fehler und Timeout")
@MainActor
func check24JavaScriptConditionDistinguishesErrorAndTimeout() async {
    let webView = WKWebView()

    let errorResult = await webView.waitForJavaScriptCondition(
        "throw new Error('condition failed')",
        timeoutSeconds: 0.01,
        pollIntervalSeconds: 0.001
    )
    let timeoutResult = await webView.waitForJavaScriptCondition(
        "false",
        timeoutSeconds: 0.01,
        pollIntervalSeconds: 0.001
    )

    #expect(errorResult == .javaScriptError)
    #expect(timeoutResult == .timedOut)
}

@Test("Check24 JavaScript-Bedingung reagiert auf Cancellation")
@MainActor
func check24JavaScriptConditionReturnsCancellation() async {
    let webView = WKWebView()
    let signal = AsyncStream<Void>.makeStream()
    let task = Task { @MainActor in
        await webView.waitForJavaScriptCondition(
            "false",
            timeoutSeconds: 20,
            pollIntervalSeconds: 0.1,
            onPollStarted: {
                signal.continuation.yield()
            }
        )
    }
    var iterator = signal.stream.makeAsyncIterator()
    _ = await iterator.next()
    task.cancel()

    let result = await task.value
    #expect(result == .cancelled)
}
