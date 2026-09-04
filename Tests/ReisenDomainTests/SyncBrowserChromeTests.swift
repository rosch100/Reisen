import Testing
import ReisenDomain

@Test func syncBrowserChrome_hidesCollapseControlWhileLoginRequired() {
    #expect(!SyncBrowserChrome.showsCollapseControl(isSessionReady: false))
}

@Test func syncBrowserChrome_showsCollapseControlWhenSessionReady() {
    #expect(SyncBrowserChrome.showsCollapseControl(isSessionReady: true))
}

@Test func syncBrowserChrome_keepsBrowserExpandedWhileLoginRequired() {
    #expect(SyncBrowserChrome.isBrowserExpanded(
        isSessionReady: false,
        userExpanded: false
    ))
    #expect(SyncBrowserChrome.isBrowserExpanded(
        isSessionReady: false,
        userExpanded: true
    ))
}

@Test func syncBrowserChrome_respectsUserExpansionWhenSessionReady() {
    #expect(!SyncBrowserChrome.isBrowserExpanded(
        isSessionReady: true,
        userExpanded: false
    ))
    #expect(SyncBrowserChrome.isBrowserExpanded(
        isSessionReady: true,
        userExpanded: true
    ))
}

@Test func syncBrowserChrome_showsLoginChromeAboveWebViewWhileLoginRequired() {
    #expect(SyncBrowserChrome.showsLoginChromeAboveWebView(isSessionReady: false))
    #expect(!SyncBrowserChrome.showsLoginChromeAboveWebView(isSessionReady: true))
}

@Test func syncBrowserChrome_hidesBottomActionBarWhileLoginRequired() {
    #expect(!SyncBrowserChrome.showsBottomActionBar(isSessionReady: false))
    #expect(SyncBrowserChrome.showsBottomActionBar(isSessionReady: true))
}
