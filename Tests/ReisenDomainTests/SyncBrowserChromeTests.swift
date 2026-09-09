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

/// Regression HIG: Phone-Portrait darf nicht mit Side-by-Side-Annahme starten (Zeichen-Wrap-CTAs).
@Test func syncBrowserChrome_initialAvailableWidthAssumesStackedUntilMeasured() {
    #expect(SyncBrowserChrome.initialAvailableWidthAssumption < SyncBrowserChrome.sideBySideMinimumWidth)
    #expect(
        SyncBrowserChrome.loginChromeArrangement(
            availableWidth: SyncBrowserChrome.initialAvailableWidthAssumption
        ) == .stacked
    )
    // iPhone-Breitenklasse bleibt stacked
    #expect(SyncBrowserChrome.loginChromeArrangement(availableWidth: 390) == .stacked)
    #expect(SyncBrowserChrome.loginChromeArrangement(availableWidth: 430) == .stacked)
}

@Test func syncBrowserChrome_loginChromeArrangementStacksForAccessibilityText() {
    #expect(
        SyncBrowserChrome.loginChromeArrangement(
            availableWidth: 900,
            prefersStackedForAccessibilityText: true
        ) == .stacked
    )
}

/// Side-by-Side erst wenn Status + Credential-CTAs (DE-Labels) ohne Kompression passen.
@Test func syncBrowserChrome_sideBySideMinimumFitsCredentialColumn() {
    #expect(
        SyncBrowserChrome.sideBySideMinimumWidth
            >= SyncBrowserChrome.statusColumnMinimumWidth
            + SyncBrowserChrome.credentialsColumnMinimumWidth
            + SyncBrowserChrome.sideBySideSpacing
    )
    #expect(SyncBrowserChrome.loginChromeCredentialsUseIntrinsicWidth)
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

/// Regression: collapsed Browser darf Session-Banner nicht vertikal zentrieren.
@Test func syncBrowserChrome_contentStackPinsToTopWhenBrowserCollapsed() {
    #expect(
        SyncBrowserChrome.contentStackVerticalAlignment(isBrowserExpanded: false) == .top
    )
    #expect(
        SyncBrowserChrome.contentStackVerticalAlignment(isBrowserExpanded: true) == .top
    )
}

/// Regression: Form-Accessory / Tastatur am unteren Rand überdeckt Floating-TabBar.
@Test func syncBrowserChrome_detectsKeyboardChromeOccupyingScreenBottom() {
    let screenMinY = 0.0
    let screenMaxY = 852.0
    // Soft-Keyboard (~336pt) am unteren Rand
    #expect(
        SyncBrowserChrome.isKeyboardChromeOccupyingBottom(
            endFrameMinY: 516,
            endFrameMaxY: 852,
            screenMinY: screenMinY,
            screenMaxY: screenMaxY
        )
    )
    // Nur Form-Accessory (~55pt) — Hardware-Keyboard / minimierte Tastatur
    #expect(
        SyncBrowserChrome.isKeyboardChromeOccupyingBottom(
            endFrameMinY: 797,
            endFrameMaxY: 852,
            screenMinY: screenMinY,
            screenMaxY: screenMaxY
        )
    )
    // Ausgeblendet: Frame unterhalb des Screens
    #expect(
        !SyncBrowserChrome.isKeyboardChromeOccupyingBottom(
            endFrameMinY: 852,
            endFrameMaxY: 1_188,
            screenMinY: screenMinY,
            screenMaxY: screenMaxY
        )
    )
    // 1pt-Overlap zählt nicht (Rauschen)
    #expect(
        !SyncBrowserChrome.isKeyboardChromeOccupyingBottom(
            endFrameMinY: 851,
            endFrameMaxY: 852,
            screenMinY: screenMinY,
            screenMaxY: screenMaxY,
            minimumOverlap: 1
        )
    )
}

@Test func syncBrowserChrome_hidesTabBarOnlyWhenSyncSelectedAndKeyboardChromeOccupiesBottom() {
    #expect(
        SyncBrowserChrome.hidesTabBarWhileKeyboardChromeVisible(
            isSyncTabSelected: true,
            keyboardChromeOccupiesBottom: true
        )
    )
    #expect(
        !SyncBrowserChrome.hidesTabBarWhileKeyboardChromeVisible(
            isSyncTabSelected: true,
            keyboardChromeOccupiesBottom: false
        )
    )
    #expect(
        !SyncBrowserChrome.hidesTabBarWhileKeyboardChromeVisible(
            isSyncTabSelected: false,
            keyboardChromeOccupiesBottom: true
        )
    )
}

/// Regression #209 Follow-up: Keyboard-Frame allein reicht nicht — needsLogin / Web-Input-Fokus.
@Test func syncBrowserChrome_hidesTabBarForSyncNeedsLoginOrWebInputFocus() {
    #expect(
        SyncBrowserChrome.hidesTabBarForSyncBrowserChrome(
            isSyncTabSelected: true,
            needsLogin: true,
            keyboardChromeOccupiesBottom: false,
            webLoginInputFocused: false
        )
    )
    #expect(
        SyncBrowserChrome.hidesTabBarForSyncBrowserChrome(
            isSyncTabSelected: true,
            needsLogin: false,
            keyboardChromeOccupiesBottom: false,
            webLoginInputFocused: true
        )
    )
    #expect(
        !SyncBrowserChrome.hidesTabBarForSyncBrowserChrome(
            isSyncTabSelected: true,
            needsLogin: false,
            keyboardChromeOccupiesBottom: false,
            webLoginInputFocused: false
        )
    )
    #expect(
        !SyncBrowserChrome.hidesTabBarForSyncBrowserChrome(
            isSyncTabSelected: false,
            needsLogin: true,
            keyboardChromeOccupiesBottom: true,
            webLoginInputFocused: true
        )
    )
}
