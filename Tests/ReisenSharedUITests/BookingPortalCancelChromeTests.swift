import Foundation
import Testing
import ReisenDomain
@testable import ReisenSharedUI

@Test func bookingPortalCancelChrome_destructiveUsesStornierenTitle() {
    #expect(BookingPortalCancelTitle.button == L10n.string(.actionCancelInPortal))
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
    let withoutSession = BookingPortalActions.visible(
        open: url, cancellation: url, status: .confirmed,
        deadlines: [free], now: now, hasSessionWebView: false,
        linkMode: .inPageOnOpen
    )
    #expect(withoutSession.open == url && withoutSession.cancel == nil)
    #expect(
        BookingPortalActionBar.isVisible(
            open: url, cancellation: url, status: .confirmed,
            deadlines: [free], now: now, hasSessionWebView: false,
            linkMode: .inPageOnOpen
        )
    )
    let withSession = BookingPortalActions.visible(
        open: url, cancellation: url, status: .confirmed,
        deadlines: [free], now: now, hasSessionWebView: true,
        linkMode: .inPageOnOpen
    )
    #expect(withSession.cancel == url)
}

@MainActor
@Test func bookingPortalActionBar_hidesSessionBoundCancelWithoutSessionWebView() {
    let open = URL(string: "https://example.com/booking")!
    let cancel = URL(string: "https://example.com/booking/cancel")!
    let free = CancellationDeadline(
        deadlineAt: Date().addingTimeInterval(86_400),
        isFreeCancellation: true
    )
    #expect(
        !BookingPortalActionBar.isVisible(
            open: nil,
            cancellation: cancel,
            status: .confirmed,
            deadlines: [free],
            now: Date(),
            hasSessionWebView: false,
            linkMode: .sessionBoundDistinct
        )
    )
    #expect(
        BookingPortalActionBar.isVisible(
            open: open,
            cancellation: cancel,
            status: .confirmed,
            deadlines: [free],
            now: Date(),
            hasSessionWebView: false,
            linkMode: .sessionBoundDistinct
        )
    )
    let shown = BookingPortalActions.visible(
        open: open,
        cancellation: cancel,
        status: .confirmed,
        deadlines: [free],
        now: Date(),
        hasSessionWebView: false,
        linkMode: .sessionBoundDistinct
    )
    #expect(shown.open == open)
    #expect(shown.cancel == nil)
}

@Test func bookingPortalCancellation_allowsCopyingCancellationLink_hidesSameURL() {
    let url = URL(string: "https://example.com/booking")!
    #expect(
        !BookingPortalCancellation.allowsCopyingCancellationLink(
            cancel: url,
            open: url
        )
    )
    #expect(
        BookingPortalCancellation.allowsCopyingCancellationLink(
            cancel: URL(string: "https://example.com/cancel")!,
            open: url
        )
    )
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
