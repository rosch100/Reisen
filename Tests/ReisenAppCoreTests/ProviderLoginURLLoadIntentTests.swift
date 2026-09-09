import Foundation
import Testing
import ReisenAppCore

private let login = URL(string: "https://account.check24.de/login")!
private let oauth = "https://appleid.apple.com/auth"

@Test func providerLoginURLLoadIntent_skipsWithoutEmbedOrURL() {
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: false,
            coordinatorLoadedURL: nil,
            hubRequestedURL: nil,
            webViewURLString: nil,
            isLoading: false
        ) == .skip
    )
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: nil,
            allowsEmbed: true,
            coordinatorLoadedURL: nil,
            hubRequestedURL: nil,
            webViewURLString: nil,
            isLoading: false
        ) == .skip
    )
}

@Test func providerLoginURLLoadIntent_firstDisplayLoadsWhenWebViewEmpty() {
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: true,
            coordinatorLoadedURL: nil,
            hubRequestedURL: nil,
            webViewURLString: nil,
            isLoading: false
        ) == .load(login)
    )
}

/// First-Enable/Reparent-Race: Coordinator meint schon geladen, WKWebView ist noch leer.
@Test func providerLoginURLLoadIntent_recoversBlankAfterCoordinatorMarkedLoaded() {
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: true,
            coordinatorLoadedURL: login,
            hubRequestedURL: login,
            webViewURLString: nil,
            isLoading: false
        ) == .load(login)
    )
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: true,
            coordinatorLoadedURL: login,
            hubRequestedURL: login,
            webViewURLString: "about:blank",
            isLoading: false
        ) == .load(login)
    )
}

/// make→update: nach load ist URL noch leer, aber Navigation läuft — kein zweites load.
@Test func providerLoginURLLoadIntent_skipsBlankWhileLoading() {
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: true,
            coordinatorLoadedURL: login,
            hubRequestedURL: login,
            webViewURLString: nil,
            isLoading: true
        ) == .skip
    )
}

@Test func providerLoginURLLoadIntent_remountSkipsWhenPageAlreadyAtLogin() {
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: true,
            coordinatorLoadedURL: nil,
            hubRequestedURL: login,
            webViewURLString: login.absoluteString,
            isLoading: false
        ) == .markLoaded
    )
}

@Test func providerLoginURLLoadIntent_remountSkipsOauthNavigation() {
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: true,
            coordinatorLoadedURL: nil,
            hubRequestedURL: login,
            webViewURLString: oauth,
            isLoading: false
        ) == .markLoaded
    )
}

@Test func providerLoginURLLoadIntent_providerSwitchLoadsNewURL() {
    let other = URL(string: "https://www.opodo.de/travel/secure/login")!
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: other,
            allowsEmbed: true,
            coordinatorLoadedURL: login,
            hubRequestedURL: login,
            webViewURLString: login.absoluteString,
            isLoading: false
        ) == .load(other)
    )
}

@Test func providerLoginURLLoadIntent_sameIntentWithMatchingPageSkips() {
    #expect(
        ProviderLoginURLLoadIntent.decide(
            loginURL: login,
            allowsEmbed: true,
            coordinatorLoadedURL: login,
            hubRequestedURL: login,
            webViewURLString: login.absoluteString,
            isLoading: false
        ) == .skip
    )
}
