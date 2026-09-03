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
        await recordDiagnosticPhase(
            "hotel_detail",
            event: "started",
            result: .started,
            url: bookingURL
        )
        let alreadyThere = webView.url?.absoluteString == bookingURL.absoluteString
            || (webView.url?.path == bookingURL.path && webView.url?.host == bookingURL.host)
        if !alreadyThere {
            try await load(url: bookingURL, in: webView)
        }

        await dismissBookingChooserIfNeeded(in: webView, for: parsedBooking)
        guard try await waitForHotelDetailReady(in: webView) else {
            await recordDiagnosticPhase(
                "hotel_detail",
                event: "readiness_failed",
                result: .failed,
                url: bookingURL,
                reason: "readiness_condition_false"
            )
            return
        }
        // Soft: Preis/Storno kann vor hotelInfo (Adresse oder Check-in/out) im DOM stehen.
        _ = try await waitForHotelInfoAddressPayload(in: webView)

        let detailSnapshot = try await snapshotHTML(from: webView)
        let html = detailSnapshot.html

        let parsedBasket = HotelBasketParser.parse(from: html)
        let basketId = parsedBasket?.basketId

        let policy = CancellationPolicyParser().parseCancellationPolicy(from: html)
        let parsedDetails = BookingDetailsParser().parse(from: html, bookingType: parsedBooking.type)
        let stay = HotelCheckInOutParser().parse(from: html)
            .merging(place: Check24HotelInfoParser.parse(from: html))
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
        await recordDiagnosticPhase(
            "hotel_detail",
            event: "completed",
            result: .succeeded,
            url: bookingURL,
            reason: hotelDetailCompletionReason(stay: stay, details: parsedDetails)
        )
    }

    func hotelDetailCompletionReason(stay: HotelCheckInOut, details: ParsedBookingDetails) -> String {
        [
            presenceFlag("hotel_info_address", stay.locationToAddress != nil),
            presenceFlag("check_in_minutes", stay.checkInMinutes != nil),
            presenceFlag("check_out_minutes", stay.checkOutMinutes != nil),
            presenceFlag("board_type", details.boardTypeRaw != nil),
            presenceFlag("room_category", details.roomCategory != nil),
        ].joined(separator: "|")
    }

    private func presenceFlag(_ key: String, _ present: Bool) -> String {
        present ? "\(key)_present" : "\(key)_missing"
    }

    func waitForHotelDetailReady(in webView: WKWebView) async throws -> Bool {
        try await webView.waitForJavaScriptCondition(
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
        ).asReadyFlag()
    }

    /// Wartet auf eingebettetes `hotelInfo` inkl. Straße. Timeout → false (Parse trotzdem versuchen).
    func waitForHotelInfoAddressPayload(in webView: WKWebView) async throws -> Bool {
        try await webView.waitForJavaScriptCondition(
            Check24HotelInfoParser.domAddressPayloadCondition,
            timeoutSeconds: 8
        ).asReadyFlag()
    }
}
