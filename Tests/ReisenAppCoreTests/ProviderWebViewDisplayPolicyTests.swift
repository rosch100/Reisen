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

/// Regression: Probe darf die Hub-WebView des sichtbaren Sync-Providers nicht stehlen
/// (iOS Login/OTP → schwarze Sync-Fläche bei needsLogin).
@Test func providerWebViewDisplayPolicy_probeMustNotEmbedForegroundSyncProvider() {
    #expect(
        !ProviderWebViewDisplayPolicy.allowsEmbed(
            owner: .syncHost,
            host: .probe,
            providerID: .traveloka,
            foregroundSyncProviderID: .traveloka
        )
    )
    #expect(
        ProviderWebViewDisplayPolicy.allowsEmbed(
            owner: .syncHost,
            host: .sync,
            providerID: .traveloka,
            foregroundSyncProviderID: .traveloka
        )
    )
    #expect(
        ProviderWebViewDisplayPolicy.allowsEmbed(
            owner: .syncHost,
            host: .probe,
            providerID: .check24,
            foregroundSyncProviderID: .traveloka
        )
    )
    #expect(
        ProviderWebViewDisplayPolicy.allowsEmbed(
            owner: .syncHost,
            host: .probe,
            providerID: .traveloka,
            foregroundSyncProviderID: nil
        )
    )
}

@Test @MainActor func providerSessionHub_displayOwnerDefaultsToSyncHostAndResets() {
    let hub = ProviderSessionHub()
    #expect(hub.webViewDisplayOwner == .syncHost)
    hub.setWebViewDisplayOwner(.cancelSheet)
    #expect(hub.webViewDisplayOwner == .cancelSheet)
    hub.setWebViewDisplayOwner(.syncHost)
    #expect(hub.webViewDisplayOwner == .syncHost)
}

@Test @MainActor func providerSessionHub_foregroundClaimBlocksProbeEmbed() {
    let hub = ProviderSessionHub()
    hub.syncEnabledProviders([.traveloka, .check24])
    #expect(hub.allowsEmbed(on: .probe, providerID: .traveloka))
    hub.setForegroundSyncProviderID(.traveloka)
    #expect(!hub.allowsEmbed(on: .probe, providerID: .traveloka))
    #expect(hub.allowsEmbed(on: .sync, providerID: .traveloka))
    #expect(hub.allowsEmbed(on: .probe, providerID: .check24))
    hub.setForegroundSyncProviderID(nil)
    #expect(hub.allowsEmbed(on: .probe, providerID: .traveloka))
}

@Test @MainActor func providerSessionHub_hasSessionWebViewReflectsSlot() {
    let hub = ProviderSessionHub()
    hub.syncEnabledProviders([.check24])
    #expect(!hub.hasSessionWebView(for: .check24))
    hub.updateWebView(.check24, webView: WKWebView())
    #expect(!hub.hasSessionWebView(for: .check24))
    hub.updateStatus(.check24, status: .sessionReady)
    #expect(hub.hasSessionWebView(for: .check24))
}
