import Foundation
import ReisenDomain
import ReisenData

public struct BookingPortalCancelRequest: Identifiable, Equatable, Sendable {
    public var id: URL { url }
    public var providerID: ProviderID
    public var url: URL

    public init(providerID: ProviderID, url: URL) {
        self.providerID = providerID
        self.url = url
    }

    public static func handle(
        _ presentation: BookingPortalCancelPresentation,
        url: URL,
        providerID: ProviderID,
        openURL: (URL) -> Void,
        presentSheet: (BookingPortalCancelRequest) -> Void
    ) {
        switch presentation {
        case .sheet:
            presentSheet(BookingPortalCancelRequest(providerID: providerID, url: url))
        case .safari:
            openURL(url)
        case .hidden:
            break
        }
    }

    public static func handle(
        _ presentation: BookingPortalCancelPresentation,
        url: URL,
        booking: SDBooking,
        openURL: (URL) -> Void,
        presentSheet: (BookingPortalCancelRequest) -> Void
    ) {
        handle(
            presentation,
            url: url,
            providerID: booking.provider,
            openURL: openURL,
            presentSheet: presentSheet
        )
    }

    /// UI-Einstieg: Storno aus persistierter Buchung (Presentation + URL aus Booking).
    public static func present(
        for booking: SDBooking,
        hasSessionWebView: Bool,
        openURL: (URL) -> Void,
        setCancelRequest: (BookingPortalCancelRequest?) -> Void,
        now: Date = Date()
    ) {
        guard let url = booking.cancellationBrowserURL else { return }
        handle(
            booking.portalCancelPresentation(hasSessionWebView: hasSessionWebView, now: now),
            url: url,
            booking: booking,
            openURL: openURL,
            presentSheet: { setCancelRequest($0) }
        )
    }

    /// UI-Einstieg: Storno aus ActionBar/Menu (Presentation bereits berechnet).
    public static func route(
        _ presentation: BookingPortalCancelPresentation,
        url: URL,
        booking: SDBooking,
        openURL: (URL) -> Void,
        setCancelRequest: (BookingPortalCancelRequest?) -> Void
    ) {
        handle(
            presentation,
            url: url,
            booking: booking,
            openURL: openURL,
            presentSheet: { setCancelRequest($0) }
        )
    }
}
