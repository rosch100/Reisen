import Foundation
import Testing
import ReisenDomain

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let open = URL(string: "https://example.com/open")!
private let cancel = URL(string: "https://example.com/cancel")!

private func freeDeadline(days: Int = 2) -> CancellationDeadline {
    CancellationDeadline(
        deadlineAt: now.addingTimeInterval(TimeInterval(days * 86_400)),
        isFreeCancellation: true
    )
}

private func paid(amount: Double?, days: Int = 3) -> CancellationDeadline {
    CancellationDeadline(
        deadlineAt: now.addingTimeInterval(TimeInterval(days * 86_400)),
        isFreeCancellation: false,
        cancellationFeeAmount: amount
    )
}

@Test func bookingCancellationBrowserURL_usesSameFilterAsOpen() {
    var booking = Booking(
        provider: .traveloka,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2)
    )
    booking.cancellationUrl = "https://www.traveloka.com/en-en/refund/presubmission/HOTEL/a/b"
    #expect(booking.cancellationBrowserURL?.absoluteString == booking.cancellationUrl)

    booking.cancellationUrl = BookingExternalURL.makeManual()
    #expect(booking.cancellationBrowserURL == nil)
    booking.cancellationUrl = "   "
    #expect(booking.cancellationBrowserURL == nil)
}

@Test func bookingCancellationBrowserURL_keepsOpodoHashFragment() {
    var booking = Booking(
        provider: .opodo,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2)
    )
    let raw = "https://www.opodo.de/travel/secure/#tripdetails/td=token&funnel=cancellationHSA"
    booking.cancellationUrl = raw
    #expect(booking.cancellationBrowserURL?.absoluteString == raw)
    #expect(booking.cancellationBrowserURL?.fragment?.contains("funnel=cancellationHSA") == true)
}

@Test func bookingPortalCancellation_isActionable_requiresDisplayableDeadline() {
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [freeDeadline()], now: now
        )
    )
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: open, open: open, status: .confirmed,
            deadlines: [freeDeadline()], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .cancelled,
            deadlines: [freeDeadline()], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: nil, open: open, status: .confirmed,
            deadlines: [freeDeadline()], now: now
        )
    )
}

@Test func bookingPortalCancellation_isActionable_deadlineVariants() {
    let expired = CancellationDeadline(
        deadlineAt: now.addingTimeInterval(-86_400),
        isFreeCancellation: true
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [expired], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [paid(amount: 100)], now: now
        )
    )
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [paid(amount: 50), paid(amount: 100)], now: now
        )
    )
    #expect(
        BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [freeDeadline(), paid(amount: 100)], now: now
        )
    )
    #expect(
        !BookingPortalCancellation.isActionable(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: [paid(amount: nil)], now: now
        )
    )
}

@Test func bookingPortalCancellation_presentation_routesSheetSafariHidden() {
    let deadlines = [freeDeadline()]
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: open, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: true,
            linkMode: .distinctURL
        ) == .sheet
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: open, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: false,
            linkMode: .distinctURL
        ) == .hidden
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: false,
            linkMode: .distinctURL
        ) == .safari
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: true,
            linkMode: .distinctURL
        ) == .sheet
    )
}

@Test func bookingPortalActions_visible_usesPresentation() {
    let deadlines = [freeDeadline()]
    let both = BookingPortalActions.visible(
        open: open, cancellation: cancel, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: true,
        linkMode: .distinctURL
    )
    #expect(both.open == open && both.cancel == cancel)

    let sameNoHub = BookingPortalActions.visible(
        open: open, cancellation: open, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: false,
        linkMode: .distinctURL
    )
    #expect(sameNoHub.open == open && sameNoHub.cancel == nil)

    let sameHub = BookingPortalActions.visible(
        open: open, cancellation: open, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: true,
        linkMode: .distinctURL
    )
    #expect(sameHub.open == open && sameHub.cancel == open)

    let onlyCancel = BookingPortalActions.visible(
        open: nil, cancellation: cancel, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: false,
        linkMode: .distinctURL
    )
    #expect(onlyCancel.open == nil && onlyCancel.cancel == cancel)

    let cancelled = BookingPortalActions.visible(
        open: open, cancellation: cancel, status: .cancelled,
        deadlines: deadlines, now: now, hasSessionWebView: true,
        linkMode: .distinctURL
    )
    #expect(cancelled.open == open && cancelled.cancel == nil)
}

@Test func bookingPortalCancellation_presentation_sessionBoundHidesSafari() {
    let deadlines = [freeDeadline()]
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: false,
            linkMode: .sessionBoundDistinct
        ) == .hidden
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: true,
            linkMode: .sessionBoundDistinct
        ) == .sheet
    )
}

@Test func bookingPortalCancellation_presentation_noneModeHidesEvenWithDistinctURL() {
    let deadlines = [freeDeadline()]
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: false,
            linkMode: .none
        ) == .hidden
    )
    #expect(
        BookingPortalCancellation.presentation(
            cancellation: cancel, open: open, status: .confirmed,
            deadlines: deadlines, now: now, hasSessionWebView: true,
            linkMode: .none
        ) == .hidden
    )
    let shown = BookingPortalActions.visible(
        open: open, cancellation: cancel, status: .confirmed,
        deadlines: deadlines, now: now, hasSessionWebView: false,
        linkMode: .none
    )
    #expect(shown.open == open && shown.cancel == nil)
}

@Test func bookingPortalCancellation_allowsCopyingCancellationLink() {
    #expect(
        BookingPortalCancellation.allowsCopyingCancellationLink(cancel: cancel, open: open)
    )
    #expect(
        !BookingPortalCancellation.allowsCopyingCancellationLink(cancel: open, open: open)
    )
    #expect(
        !BookingPortalCancellation.allowsCopyingCancellationLink(cancel: nil, open: open)
    )
}
