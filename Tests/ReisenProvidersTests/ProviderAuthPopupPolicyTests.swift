import Foundation
import Testing
import ReisenProviders

@Test func providerAuthPopupPolicy_presentsChildForAllowedBlankTarget() {
    let url = URL(string: "https://www.getyourguide.com/login")!
    let action = ProviderAuthPopupPolicy.createAction(
        requestURL: url,
        allows: { ProviderWebViewNavigationPolicy.allows($0, isMainFrame: true) }
    )
    #expect(action == .presentChild)
}

@Test func providerAuthPopupPolicy_blocksDisallowedBlankTarget() {
    let url = URL(string: "booking://open")!
    let action = ProviderAuthPopupPolicy.createAction(
        requestURL: url,
        allows: { ProviderWebViewNavigationPolicy.allows($0, isMainFrame: true) }
    )
    #expect(action == .block)
}

@Test func providerAuthPopupPolicy_blocksMissingRequestURL() {
    let action = ProviderAuthPopupPolicy.createAction(
        requestURL: nil,
        allows: { _ in true }
    )
    #expect(action == .block)
}

@Test func providerAuthPopupPolicy_keepsChildOpenOnIdentityProvider() {
    let child = URL(string: "https://appleid.apple.com/auth/authorize")!
    let parent = URL(string: "https://www.getyourguide.com/login")!
    #expect(
        !ProviderAuthPopupPolicy.shouldDismissChildAfterLoad(
            childURL: child,
            parentURL: parent,
            sawIdentityProvider: true
        )
    )
}

@Test func providerAuthPopupPolicy_keepsChildOpenBeforeIdentityProvider() {
    let child = URL(string: "https://auth.getyourguide.com/callback")!
    let parent = URL(string: "https://www.getyourguide.com/login")!
    #expect(
        !ProviderAuthPopupPolicy.shouldDismissChildAfterLoad(
            childURL: child,
            parentURL: parent,
            sawIdentityProvider: false
        )
    )
}

@Test func providerAuthPopupPolicy_dismissesAfterAppleReturnToGetYourGuideAuth() {
    let child = URL(string: "https://auth.getyourguide.com/oauth/callback")!
    let parent = URL(string: "https://www.getyourguide.com/login")!
    #expect(
        ProviderAuthPopupPolicy.shouldDismissChildAfterLoad(
            childURL: child,
            parentURL: parent,
            sawIdentityProvider: true
        )
    )
}

@Test func providerAuthPopupPolicy_doesNotDismissUnrelatedHostAfterIdP() {
    let child = URL(string: "https://evil.example/phish")!
    let parent = URL(string: "https://www.getyourguide.com/login")!
    #expect(
        !ProviderAuthPopupPolicy.shouldDismissChildAfterLoad(
            childURL: child,
            parentURL: parent,
            sawIdentityProvider: true
        )
    )
}

@Test func providerAuthPopupPolicy_tracksIdentityProviderSighting() {
    #expect(
        !ProviderAuthPopupPolicy.noteIdentityProviderSighting(
            currentURL: URL(string: "https://www.getyourguide.com/login")!,
            alreadySawIdentityProvider: false
        )
    )
    #expect(
        ProviderAuthPopupPolicy.noteIdentityProviderSighting(
            currentURL: URL(string: "https://appleid.apple.com/auth")!,
            alreadySawIdentityProvider: false
        )
    )
    #expect(
        ProviderAuthPopupPolicy.noteIdentityProviderSighting(
            currentURL: URL(string: "https://www.getyourguide.com/login")!,
            alreadySawIdentityProvider: true
        )
    )
}
