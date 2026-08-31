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
