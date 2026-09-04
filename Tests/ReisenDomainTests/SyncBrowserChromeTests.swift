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

@Test func syncBrowserChrome_prefersSideBySideWhenWidthAllows() {
    #expect(!SyncBrowserChrome.prefersSideBySideLoginChrome(availableWidth: 320))
    #expect(!SyncBrowserChrome.prefersSideBySideLoginChrome(
        availableWidth: SyncBrowserChrome.sideBySideMinimumWidth - 1
    ))
    #expect(SyncBrowserChrome.prefersSideBySideLoginChrome(
        availableWidth: SyncBrowserChrome.sideBySideMinimumWidth
    ))
    #expect(SyncBrowserChrome.prefersSideBySideLoginChrome(availableWidth: 900))
}

/// Regression #145: Arrangement nur über gemessene Breite (kein ViewThatFits+minWidth-Hack).
@Test func syncBrowserChrome_loginChromeArrangementFollowsMeasuredWidth() {
    #expect(
        SyncBrowserChrome.loginChromeArrangement(availableWidth: 320) == .stacked
    )
    #expect(
        SyncBrowserChrome.loginChromeArrangement(
            availableWidth: SyncBrowserChrome.sideBySideMinimumWidth - 1
        ) == .stacked
    )
    #expect(
        SyncBrowserChrome.loginChromeArrangement(
            availableWidth: SyncBrowserChrome.sideBySideMinimumWidth
        ) == .sideBySide
    )
    #expect(
        SyncBrowserChrome.loginChromeArrangement(availableWidth: 900) == .sideBySide
    )
}

@Test func syncBrowserChrome_showsFillCredentialsOnlyWhenAccountsExist() {
    #expect(!SyncBrowserChrome.showsFillCredentialsControl(accountCount: 0))
    #expect(SyncBrowserChrome.showsFillCredentialsControl(accountCount: 1))
    #expect(SyncBrowserChrome.showsFillCredentialsControl(accountCount: 3))
}

@Test func syncBrowserChrome_showsAccountPickerOnlyForMultipleAccounts() {
    #expect(!SyncBrowserChrome.showsAccountPicker(accountCount: 0))
    #expect(!SyncBrowserChrome.showsAccountPicker(accountCount: 1))
    #expect(SyncBrowserChrome.showsAccountPicker(accountCount: 2))
}

@Test func syncBrowserChrome_showsSelectedAccountLabelForSingleAccount() {
    #expect(!SyncBrowserChrome.showsSelectedAccountLabel(accountCount: 0))
    #expect(SyncBrowserChrome.showsSelectedAccountLabel(accountCount: 1))
    #expect(!SyncBrowserChrome.showsSelectedAccountLabel(accountCount: 2))
}

@Test func syncBrowserChrome_showsRememberLoginInBottomBarOnlyWhenSessionReady() {
    #expect(!SyncBrowserChrome.showsRememberLoginInBottomBar(isSessionReady: false))
    #expect(SyncBrowserChrome.showsRememberLoginInBottomBar(isSessionReady: true))
}
