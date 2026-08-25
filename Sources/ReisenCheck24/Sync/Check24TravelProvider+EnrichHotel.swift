import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

extension Check24TravelProvider {
    func enrichHotelDetail(
        webView: WKWebView,
        parsedBooking: ParsedBooking,
        bookingURL: URL,
        bookingURLString: String,
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: inout [String: HotelCheckInOut],
        guestHintsByBookingURL: inout [String: [BookingGuestHint]],
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails],

        basketsByBasketId: inout [String: HotelBasketParser.ParsedHotelBasket],
        bookingUuidToBasketId: inout [String: String],
        canonicalBookingUuidByBasketId: inout [String: String],
        deadlinesByBasketId: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: inout [String: HotelCheckInOut],
        guestHintsByBasketId: inout [String: [BookingGuestHint]],
        bookingDetailsByBasketId: inout [String: ParsedBookingDetails]
    ) async throws {
        let alreadyThere = webView.url?.absoluteString == bookingURL.absoluteString
            || (webView.url?.path == bookingURL.path && webView.url?.host == bookingURL.host)
        if !alreadyThere {
            try await load(url: bookingURL, in: webView)
        }

        await dismissBookingChooserIfNeeded(in: webView, for: parsedBooking)
        _ = await waitForHotelDetailReady(in: webView)

        let detailSnapshot = try await snapshotHTML(from: webView)
        let html = detailSnapshot.html

        let parsedBasket = HotelBasketParser.parse(from: html)
        let basketId = parsedBasket?.basketId

        let policy = CancellationPolicyParser().parseCancellationPolicy(from: html)
        let parsedDetails = BookingDetailsParser().parse(from: html, bookingType: parsedBooking.type)
        let stay = HotelCheckInOutParser().parse(from: html)
        let guestHints = StayHintHTMLExtractor.extract(
            from: html,
            providerRaw: ProviderID.check24.rawValue
        )

        if let basketId {
            persistBasketState(
                basketId: basketId,
                parsedBasket: parsedBasket,
                bookingURLString: bookingURLString,
                basketsByBasketId: &basketsByBasketId,
                bookingUuidToBasketId: &bookingUuidToBasketId,
                canonicalBookingUuidByBasketId: &canonicalBookingUuidByBasketId
            )

            persistBasketDetails(
                basketId: basketId,
                parsedDetails: parsedDetails,
                policyDeadlines: policy.deadlines,
                stay: stay,
                bookingURLString: bookingURLString,
                bookingDetailsByBasketId: &bookingDetailsByBasketId,
                deadlinesByBasketId: &deadlinesByBasketId,
                deadlinesByBookingURL: &deadlinesByBookingURL,
                hotelStayByBasketId: &hotelStayByBasketId,
                hotelStayByBookingURL: &hotelStayByBookingURL,
                guestHintsByBasketId: &guestHintsByBasketId,
                guestHintsByBookingURL: &guestHintsByBookingURL,
                guestHints: guestHints
            )
        } else {
            persistNonBasketDetails(
                parsedBooking: parsedBooking,
                parsedDetails: parsedDetails,
                stay: stay,
                policyDeadlines: policy.deadlines,
                bookingURLString: bookingURLString,
                bookingDetailsByBookingKey: &bookingDetailsByBookingKey,
                hotelStayByBookingURL: &hotelStayByBookingURL,
                deadlinesByBookingURL: &deadlinesByBookingURL,
                guestHintsByBookingURL: &guestHintsByBookingURL,
                guestHints: guestHints
            )
        }
    }

    func waitForHotelDetailReady(in webView: WKWebView) async -> Bool {
        await webView.waitForJavaScriptCondition(
            """
            document.documentElement.outerHTML.includes('cancelationLabelFee') ||
            document.documentElement.outerHTML.includes('cancelationLabelTime') ||
            document.documentElement.outerHTML.includes('cancelableUntilHotel') ||
            document.documentElement.outerHTML.includes('cancelableUntilUtc') ||
            document.documentElement.outerHTML.includes('basketContainer') ||
            document.documentElement.outerHTML.includes('a12524652-total') ||
            document.documentElement.outerHTML.includes('effektiver Preis') ||
            document.documentElement.outerHTML.includes('Gesamtpreis') ||
            document.documentElement.outerHTML.includes('€')
            """,
            timeoutSeconds: 12
        )
    }
}
