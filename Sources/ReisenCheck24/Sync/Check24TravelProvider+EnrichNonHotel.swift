import Foundation
import WebKit

extension Check24TravelProvider {
    func enrichNonHotelDetail(
        webView: WKWebView,
        parsedBooking: ParsedBooking,
        bookingURL: URL,
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails]
    ) async throws {
        let alreadyThere = webView.url?.absoluteString == bookingURL.absoluteString
            || (webView.url?.path == bookingURL.path && webView.url?.host == bookingURL.host)
        if !alreadyThere {
            try await load(url: bookingURL, in: webView)
        }

        let hasDetailsData = await webView.waitForJavaScriptCondition(
            """
            document.documentElement.outerHTML.includes('thirdViewData') &&
            document.documentElement.outerHTML.includes('bookingInfo')
            """,
            timeoutSeconds: 8
        )
        guard hasDetailsData else { return }

        let detailSnapshot = try await snapshotHTML(from: webView)
        let parsedDetails = BookingDetailsParser().parse(
            from: detailSnapshot.html,
            bookingType: parsedBooking.type
        )
        if let key = parsedBooking.identityKey {
            bookingDetailsByBookingKey[key] = parsedDetails
        }
    }
}
