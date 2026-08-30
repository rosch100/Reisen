import Foundation
import Testing
import ReisenDomain

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

@Test func bookingPortalActions_visible_coversOnlyCancelAndNeither() {
    let open = URL(string: "https://example.com/open")!
    let cancel = URL(string: "https://example.com/cancel")!
    let both = BookingPortalActions.visible(open: open, cancellation: cancel, status: .confirmed)
    #expect(both.open == open && both.cancel == cancel)
    let onlyCancel = BookingPortalActions.visible(open: nil, cancellation: cancel, status: .confirmed)
    #expect(onlyCancel.open == nil && onlyCancel.cancel == cancel)
    let neither = BookingPortalActions.visible(open: nil, cancellation: nil, status: .confirmed)
    #expect(neither.open == nil && neither.cancel == nil)
    let cancelled = BookingPortalActions.visible(open: open, cancellation: cancel, status: .cancelled)
    #expect(cancelled.open == open && cancelled.cancel == nil)
    let same = BookingPortalActions.visible(open: open, cancellation: open, status: .confirmed)
    #expect(same.open == open && same.cancel == nil)
}
