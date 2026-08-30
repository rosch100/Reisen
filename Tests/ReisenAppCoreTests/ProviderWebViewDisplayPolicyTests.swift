import Testing
import WebKit
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

@Test @MainActor func providerSessionHub_hasSessionWebViewReflectsSlot() {
    let hub = ProviderSessionHub()
    hub.syncEnabledProviders([.check24])
    #expect(!hub.hasSessionWebView(for: .check24))
    hub.updateWebView(.check24, webView: WKWebView())
    #expect(hub.hasSessionWebView(for: .check24))
}
