import Foundation
import Testing
import ReisenDomain
@testable import ReisenSharedUI

@Test func bookingPortalCancelChrome_destructiveUsesStornierenTitle() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }
    #expect(BookingPortalCancelTitle.button == "Stornieren")
    #expect(BookingPortalCancelChrome.systemImage == "arrow.up.right.square")
    #expect(BookingPortalCancelChrome.usesDestructiveRole)
}

@MainActor
@Test func bookingPortalCancelActionBar_isVisible_sameURLRequiresSession() {
    let url = URL(string: "https://example.com/booking")!
    let free = CancellationDeadline(
        deadlineAt: Date().addingTimeInterval(86_400),
        isFreeCancellation: true
    )
    let now = Date()
    #expect(
        BookingPortalActionBar.isVisible(
            open: url, cancellation: url, status: .confirmed,
            deadlines: [free], now: now, hasSessionWebView: false
        )
    )
    let withoutSession = BookingPortalActions.visible(
        open: url, cancellation: url, status: .confirmed,
        deadlines: [free], now: now, hasSessionWebView: false
    )
    #expect(withoutSession.open == url && withoutSession.cancel == nil)
    let withSession = BookingPortalActions.visible(
        open: url, cancellation: url, status: .confirmed,
        deadlines: [free], now: now, hasSessionWebView: true
    )
    #expect(withSession.cancel == url)
}

@Test func bookingPortalCancelRequest_handle_sheetDoesNotOpenURL() {
    let url = URL(string: "https://example.com/cancel")!
    var opened: URL?
    var presented: BookingPortalCancelRequest?
    BookingPortalCancelRequest.handle(
        .sheet,
        url: url,
        providerID: .check24,
        openURL: { opened = $0 },
        presentSheet: { presented = $0 }
    )
    #expect(opened == nil)
    #expect(presented == BookingPortalCancelRequest(providerID: .check24, url: url))
}

@Test func bookingPortalCancelRequest_handle_safariOpensURL() {
    let url = URL(string: "https://example.com/cancel")!
    var opened: URL?
    var presented: BookingPortalCancelRequest?
    BookingPortalCancelRequest.handle(
        .safari,
        url: url,
        providerID: .check24,
        openURL: { opened = $0 },
        presentSheet: { presented = $0 }
    )
    #expect(opened == url)
    #expect(presented == nil)
}
