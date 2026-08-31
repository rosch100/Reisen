import Foundation
import WebKit

extension Check24TravelProvider {
    func enrichNonHotelDetail(
        webView: WKWebView,
        parsedBooking: ParsedBooking,
        bookingURL: URL,
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails]
    ) async throws {
        await recordDiagnosticPhase(
            "non_hotel_detail",
            event: "started",
            result: .started,
            url: bookingURL
        )
        let alreadyThere = webView.url?.absoluteString == bookingURL.absoluteString
            || (webView.url?.path == bookingURL.path && webView.url?.host == bookingURL.host)
        if !alreadyThere {
            try await load(url: bookingURL, in: webView)
        }

        guard try await waitForNonHotelDetailReady(in: webView) else {
            await recordDiagnosticPhase(
                "non_hotel_detail",
                event: "readiness_failed",
                result: .failed,
                url: bookingURL,
                reason: "readiness_condition_false"
            )
            return
        }

        let detailSnapshot = try await snapshotHTML(from: webView)
        let parsedDetails = BookingDetailsParser().parse(
            from: detailSnapshot.html,
            bookingType: parsedBooking.type
        )
        guard let key = parsedBooking.identityKey else {
            await recordDiagnosticPhase(
                "non_hotel_detail",
                event: "identity_missing",
                result: .failed,
                url: bookingURL,
                reason: "booking_identity_missing"
            )
            return
        }
        bookingDetailsByBookingKey[key] = parsedDetails
        await recordDiagnosticPhase(
            "non_hotel_detail",
            event: "completed",
            result: .succeeded,
            url: bookingURL
        )
    }

    func waitForNonHotelDetailReady(in webView: WKWebView) async throws -> Bool {
        try await webView.waitForJavaScriptCondition(
            """
            document.documentElement.outerHTML.includes('thirdViewData') &&
            document.documentElement.outerHTML.includes('bookingInfo')
            """,
            timeoutSeconds: 8
        ).asReadyFlag()
    }
}
